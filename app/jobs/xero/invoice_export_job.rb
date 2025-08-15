# app/jobs/xero/invoice_export_job.rb
require "json"
require "cgi"
module Xero
  class InvoiceExportJob < ApplicationJob
    queue_as :default

    FALLBACK_ACCOUNT_ENV = "XERO_FALLBACK_ACCOUNT_CODE".freeze
    AUTO_CREATE_CONTACTS_ENV = "XERO_AUTO_CREATE_CONTACTS".freeze
    AUTO_CREATE_ITEMS_ENV = "XERO_AUTO_CREATE_ITEMS".freeze

    def short(id)
      id.to_s.split("-").first
    end
    private :short

    def perform(invoice_export)
      connection = XeroConnection.first
      unless connection
        Rails.logger.error("[Xero::InvoiceExportJob] No XeroConnection record found; aborting job.")
        invoice_export.update(status: "failed", error_blob: "No Xero connection configured")
        return
      end

      if connection.expires_at.nil? || connection.expires_at <= Time.current + 5.minutes
        Rails.logger.info("[Xero::InvoiceExportJob] Access token near/after expiry (expires_at=#{connection.expires_at&.iso8601 || 'nil'}) — attempting refresh…")
        refreshed = refresh_token(connection)
        unless refreshed
          invoice_export.update(status: "failed", error_blob: "Failed to refresh Xero token")
          return
        end
      end

      xero_tenant_id = connection.tenant_id
      if xero_tenant_id.blank?
        Rails.logger.error("[Xero::InvoiceExportJob] Missing tenant_id on XeroConnection; aborting.")
        invoice_export.update(status: "failed", error_blob: "Missing Xero tenant id")
        return
      end
      XeroRuby.configure { |c| c.access_token = connection.access_token }
      api_client = XeroRuby::ApiClient.new
      accounting_api = XeroRuby::AccountingApi.new(api_client)

      fallback_account_code = if connection.respond_to?(:sales_account_code) && connection.sales_account_code.present?
        connection.sales_account_code
      else
        ENV[FALLBACK_ACCOUNT_ENV]
      end

      invoice_export.update(status: "processing")
      exported_count = 0
      Rails.logger.info("[Xero::InvoiceExportJob] Using tenant_id=#{xero_tenant_id} token_expires_at=#{connection.expires_at&.iso8601}")

      lines_by_location = invoice_export.invoice_export_lines.includes(:location, :area, :timesheet).group_by(&:location)
      Rails.logger.info("[Xero::InvoiceExportJob] Grouped lines by location: #{lines_by_location.transform_values { |arr| arr.size }}")

      lines_by_location.each do |location, lines|
        begin
          contact_hash = ensure_contact_hash(accounting_api, xero_tenant_id, location.name)
          Rails.logger.info("[Xero::InvoiceExportJob] Using contact #{contact_hash[:contact_id] ? 'ContactID' : 'Name'} for location='#{location&.name}'")

          Rails.logger.info("[Xero::InvoiceExportJob] Building payload for location='#{location&.name}' lines=#{lines.size}")

          item_line_items = lines.map do |line|
            # Prefer an explicit Xero item mapping if the Area has one; otherwise fall back to export_code
            mapped_code = if line.area.respond_to?(:xero_item_code) && line.area.xero_item_code.present?
              line.area.xero_item_code
            else
              line.area.export_code
            end

            {
              item_code: mapped_code,
              description: line.description,
              quantity: line.timesheet.duration_in_hours,
              tax_type: "NONE"
            }
          end

          account_line_items = lines.map do |line|
            h = {
              description: line.description,
              quantity: line.timesheet.duration_in_hours,
              unit_amount: 0.0, # replace with your rate if available
              tax_type: "NONE"
            }
            h[:account_code] = fallback_account_code if fallback_account_code.present?
            h
          end
          Rails.logger.warn("[Xero::InvoiceExportJob] No fallback account code configured; set #{FALLBACK_ACCOUNT_ENV} or connection.sales_account_code to enable account-mode retry.") if fallback_account_code.blank?

          if item_line_items.any? { |li| li[:item_code].blank? || li[:quantity].nil? }
            Rails.logger.warn("[Xero::InvoiceExportJob] One or more line items missing item_code or quantity for location='#{location&.name}'. Will try fallback account_code if configured.")
          end

          Rails.logger.debug("[Xero::InvoiceExportJob] item_line_items preview: #{item_line_items.take(3).inspect}#{item_line_items.size > 3 ? '…' : ''}")
          Rails.logger.debug("[Xero::InvoiceExportJob] account_line_items preview: #{account_line_items.take(3).inspect}#{account_line_items.size > 3 ? '…' : ''}")

          build_payload = ->(li) do
            {
              invoices: [ {
                type: "ACCREC",
                contact: contact_hash,
                date: Time.current.to_date,
                due_date: Time.current.to_date + 7.days,
                line_items: li,
                status: "DRAFT"
              } ]
            }
          end

          opts = { summarize_errors: false, unitdp: 4 }

          # Preflight diagnostics (non-fatal): check whether all item codes exist and whether the contact exists
          item_codes = item_line_items.map { |li| li[:item_code] }.compact.uniq
          missing = item_codes.reject { |code| item_exists?(accounting_api, xero_tenant_id, code) }
          Rails.logger.info("[Xero::InvoiceExportJob] Preflight items: codes=#{item_codes.inspect} missing=#{missing.inspect}") unless item_codes.empty?

          # If any items are missing, decide early how to proceed
          if missing.any?
            Rails.logger.warn("[Xero::InvoiceExportJob] Missing item codes detected preflight: #{missing.inspect}")

            # Option A: try auto-create (guarded by env var)
            if ActiveModel::Type::Boolean.new.cast(ENV[AUTO_CREATE_ITEMS_ENV])
              Rails.logger.info("[Xero::InvoiceExportJob] #{AUTO_CREATE_ITEMS_ENV}=true — attempting to auto-create missing Items: #{missing.inspect}")
              begin
                auto_create_items(accounting_api, xero_tenant_id, missing, fallback_account_code)
              rescue => e_ac
                Rails.logger.error("[Xero::InvoiceExportJob] auto_create_items failed: #{e_ac.class}: #{e_ac.message}")
              end

              # Re-check existence after auto-create (use the same multi-strategy probe)
              still_missing = missing.reject { |code| item_exists?(accounting_api, xero_tenant_id, code) }
              Rails.logger.info("[Xero::InvoiceExportJob] After auto-create, still missing: #{still_missing.inspect}")

              if still_missing.empty?
                Rails.logger.info("[Xero::InvoiceExportJob] Auto-created all missing items; proceeding with ItemCode invoice.")
              else
                missing = still_missing
              end
            end

            # Option B: if still missing and we have a fallback account code, switch to account-based line items
            if missing.any? && fallback_account_code.present?
              attempt = :account
              invoice_payload = build_payload.call(account_line_items)
              Rails.logger.warn("[Xero::InvoiceExportJob] Missing item codes #{missing.inspect}; using AccountCode=#{fallback_account_code} instead of ItemCode for location='#{location&.name}'.")
              begin
                response = accounting_api.create_invoices(xero_tenant_id, invoice_payload, opts)
                created_invoice = response.invoices&.first
                Rails.logger.info("[Xero::InvoiceExportJob] Created invoice_id=#{created_invoice&.invoice_id} for location='#{location&.name}' via fallback account mode (preflight).")
                raise "Invoice creation failed: #{response.inspect}" unless created_invoice&.invoice_id
                lines.each { |line| line.update!(xero_invoice_id: created_invoice.invoice_id) }
                exported_count += 1
                next
              rescue XeroRuby::ApiError => e2
                body2 = e2.response_body.to_s
                corr2 = (e2.response_headers || {})["xero-correlation-id"] rescue nil
                status_code2 = e2.respond_to?(:code) ? e2.code : nil
                Rails.logger.error("[Xero::InvoiceExportJob] Preflight fallback account-mode ApiError status=#{status_code2} corr=#{corr2} short_corr=#{short(corr2)} body=#{body2.presence || '(empty)'}")
                msg2 = [
                  "Error for location #{location&.name}",
                  ("status=#{status_code2}" if status_code2),
                  ("corr=#{corr2}" if corr2),
                  ("detail=missing items #{missing.inspect}"),
                  ("message=#{e2.message}" if e2.message)
                ].compact.join(" | ")
                invoice_export.update(status: "failed", error_blob: msg2)
                return
              end
            end

            # Option C: still missing and no fallback — fail fast with guidance
            if missing.any?
              msg = "Missing Xero Items #{missing.join(', ')} for location #{location&.name}; cannot create invoice with ItemCode. Either create these Items in Xero, set #{AUTO_CREATE_ITEMS_ENV}=true, or set #{FALLBACK_ACCOUNT_ENV} (or connection.sales_account_code) to use AccountCode."
              Rails.logger.error("[Xero::InvoiceExportJob] #{msg}")
              invoice_export.update(status: "failed", error_blob: msg)
              return
            end
          end

          attempt = :items
          invoice_payload = build_payload.call(item_line_items)

          Rails.logger.info("[Xero::InvoiceExportJob] POST create_invoices (#{attempt}) tenant=#{xero_tenant_id} location='#{location&.name}' opts=#{opts.inspect} payload=#{invoice_payload.to_json}")
          response = accounting_api.create_invoices(xero_tenant_id, invoice_payload, opts)

          created_invoice = response.invoices&.first
          Rails.logger.info("[Xero::InvoiceExportJob] Created invoice_id=#{created_invoice&.invoice_id} for location='#{location&.name}'")
          raise "Invoice creation failed: #{response.inspect}" unless created_invoice&.invoice_id

          lines.each { |line| line.update!(xero_invoice_id: created_invoice.invoice_id) }
          exported_count += 1

        rescue XeroRuby::ApiError => e
          body = e.response_body.to_s
          parsed = nil
          begin
            parsed = body.present? ? JSON.parse(body) : nil
          rescue JSON::ParserError
            parsed = nil
          end

          error_details = parsed&.dig("Elements", 0, "ValidationErrors") || parsed&.dig("Message") || parsed
          corr = (e.response_headers || {})["xero-correlation-id"] rescue nil
          status_code = e.respond_to?(:code) ? e.code : nil

          Rails.logger.error("[Xero::InvoiceExportJob] ApiError create_invoices(#{attempt}) tenant=#{xero_tenant_id} location='#{location&.name}' status=#{status_code} corr=#{corr} short_corr=#{short(corr)} body=#{body.presence || '(empty)'}")

          if status_code.to_i == 404 && attempt == :items
            if fallback_account_code.present?
              begin
                attempt = :account
                invoice_payload = build_payload.call(account_line_items)
                Rails.logger.warn("[Xero::InvoiceExportJob] Retrying via AccountCode=#{fallback_account_code} corr=#{short(corr)} location='#{location&.name}' payload=#{invoice_payload.to_json}")
                response = accounting_api.create_invoices(xero_tenant_id, invoice_payload, opts)
                created_invoice = response.invoices&.first
                Rails.logger.info("[Xero::InvoiceExportJob] Created invoice_id=#{created_invoice&.invoice_id} for location='#{location&.name}' via fallback account mode")
                raise "Invoice creation failed: #{response.inspect}" unless created_invoice&.invoice_id
                lines.each { |line| line.update!(xero_invoice_id: created_invoice.invoice_id) }
                exported_count += 1
                next
              rescue XeroRuby::ApiError => e2
                body2 = e2.response_body.to_s
                corr2 = (e2.response_headers || {})["xero-correlation-id"] rescue nil
                status_code2 = e2.respond_to?(:code) ? e2.code : nil
                Rails.logger.error("[Xero::InvoiceExportJob] Fallback account-mode ApiError status=#{status_code2} corr=#{corr2} short_corr=#{short(corr2)} body=#{body2.presence || '(empty)'}")
                msg2 = [
                  "Error for location #{location&.name}",
                  ("status=#{status_code2}" if status_code2),
                  ("corr=#{corr2}" if corr2),
                  ("detail=#{error_details}" if error_details),
                  ("message=#{e2.message}" if e2.message)
                ].compact.join(" | ")
                invoice_export.update(status: "failed", error_blob: msg2)
                return
              end
            else
              Rails.logger.warn("[Xero::InvoiceExportJob] 404 on items path and no fallback account code configured; cannot retry. Set #{FALLBACK_ACCOUNT_ENV} or connection.sales_account_code.")
            end
          end

          msg = [
            "Error for location #{location&.name}",
            ("status=#{status_code}" if status_code),
            ("corr=#{corr}" if corr),
            ("detail=#{error_details}" if error_details),
            ("message=#{e.message}" if e.message)
          ].compact.join(" | ")

          invoice_export.update(status: "failed", error_blob: msg)
          return
        rescue => e
          Rails.logger.error("[Xero::InvoiceExportJob] Unexpected error for location='#{location&.name}': #{e.class}: #{e.message}\n#{e.backtrace&.first}")
          invoice_export.update(status: "failed", error_blob: "Error for location #{location&.name}: #{e.message} (at #{e.backtrace&.first})")
          return
        end
      end

      invoice_export.update(status: "completed", exported_count: exported_count)
    end

    def ensure_contact_hash(accounting_api, tenant_id, name)
      # Prefer ContactID if we can find (or create) the contact; otherwise fall back to Name.
      contact = find_contact_by_name(accounting_api, tenant_id, name)
      if contact
        { contact_id: contact.contact_id }
      elsif ActiveModel::Type::Boolean.new.cast(ENV[AUTO_CREATE_CONTACTS_ENV])
        Rails.logger.info("[Xero::InvoiceExportJob] Contact '#{name}' not found; auto-creating (#{AUTO_CREATE_CONTACTS_ENV}=true).")
        payload = { contacts: [ { name: name } ] }
        begin
          resp = accounting_api.create_contacts(tenant_id, payload)
          created = resp&.contacts&.first
          if created&.contact_id
            Rails.logger.info("[Xero::InvoiceExportJob] Created contact_id=#{created.contact_id} for name='#{name}'.")
            { contact_id: created.contact_id }
          else
            Rails.logger.warn("[Xero::InvoiceExportJob] create_contacts returned no ContactID; falling back to Name.")
            { name: name }
          end
        rescue XeroRuby::ApiError => e
          corr = (e.response_headers || {})["xero-correlation-id"] rescue nil
          Rails.logger.error("[Xero::InvoiceExportJob] create_contacts ApiError corr=#{corr} body=#{e.response_body.to_s.presence || '(empty)'}; falling back to Name.")
          { name: name }
        end
      else
        Rails.logger.info("[Xero::InvoiceExportJob] Contact '#{name}' not found; using Name in payload (#{AUTO_CREATE_CONTACTS_ENV} not enabled).")
        { name: name }
      end
    end
    private :ensure_contact_hash

    def find_contact_by_name(accounting_api, tenant_id, name)
      # Build a proper `where` Hash for xero-ruby (12.x expects a Hash, not a String)
      escaped = name.to_s.gsub('"', '\\"')
      where_hash = { "Name" => %(=="#{escaped}") }
      Rails.logger.info("[Xero::InvoiceExportJob] Probe contacts where=#{where_hash.inspect}")
      Rails.logger.info("[Xero::InvoiceExportJob] Calling API: AccountingApi.get_contacts ...")
      resp = accounting_api.get_contacts(tenant_id, where: where_hash)
      contact = resp&.contacts&.find { |c| c&.name&.casecmp?(name) }
      Rails.logger.info("[Xero::InvoiceExportJob] Probe contacts result found=#{contact ? 'yes' : 'no'}")
      contact
    rescue XeroRuby::ApiError => e
      corr = (e.response_headers || {})["xero-correlation-id"] rescue nil
      status = e.respond_to?(:code) ? e.code : nil
      Rails.logger.error("[Xero::InvoiceExportJob] get_contacts ApiError status=#{status} corr=#{corr} short_corr=#{short(corr)} body=#{e.response_body.to_s.presence || '(empty)'}")
      nil
    end
    private :find_contact_by_name

    def item_exists?(accounting_api, tenant_id, code)
      return false if code.blank?

      # 1) Trust our local cache first (populated by the Xero Items sync)
      begin
        if defined?(XeroItem) && XeroItem.where(code: code).exists?
          Rails.logger.info("[Xero::InvoiceExportJob] Local cache reports item exists code=#{code.inspect}")
          return true
        end
      rescue => e
        Rails.logger.warn("[Xero::InvoiceExportJob] Local cache check failed for code=#{code.inspect}: #{e.class}: #{e.message}")
      end

      # 2) Try SDK probe (xero-ruby)
      escaped = code.to_s.gsub('"', '\\"')
      where_hash = { "Code" => %(=="#{escaped}") }
      Rails.logger.info("[Xero::InvoiceExportJob] Probe items (SDK) where=#{where_hash.inspect}")
      Rails.logger.info("[Xero::InvoiceExportJob] Calling API: AccountingApi.get_items ...")
      begin
        resp = accounting_api.get_items(tenant_id, where: where_hash)
        exists = resp&.items&.any? { |it| it&.code&.casecmp?(code) }
        Rails.logger.info("[Xero::InvoiceExportJob] SDK probe code=#{code.inspect} exists=#{exists}")
        return true if exists
      rescue XeroRuby::ApiError => e
        corr = (e.response_headers || {})["xero-correlation-id"] rescue nil
        status = e.respond_to?(:code) ? e.code : nil
        Rails.logger.warn("[Xero::InvoiceExportJob] SDK get_items ApiError code=#{code.inspect} status=#{status} corr=#{corr} short_corr=#{short(corr)} body=#{e.response_body.to_s.presence || '(empty)'}; will try HTTP fallback")
      end

      # 3) Raw HTTP fallback (works around SDK 404s)
      begin
        token = XeroConnection.first&.access_token
        raise "missing access_token" if token.blank?

        # Use a `where` to filter by exact Code, percent-encoding the value
        where_q = CGI.escape(%(Code=="#{code}"))
        url = "https://api.xero.com/api.xro/2.0/Items?where=#{where_q}"
        Rails.logger.info("[Xero::InvoiceExportJob] HTTP fallback GET #{url}")
        resp = HTTParty.get(url, headers: {
          "Authorization" => "Bearer #{token}",
          "Xero-Tenant-Id" => tenant_id,
          "Accept" => "application/json"
        })
        corr = resp.headers["xero-correlation-id"] rescue nil
        Rails.logger.info("[Xero::InvoiceExportJob] HTTP fallback status=#{resp.code} corr=#{corr} short_corr=#{short(corr)} bytes=#{resp.body.to_s.bytesize}")
        if resp.code.to_i == 200
          body = JSON.parse(resp.body) rescue {}
          items = Array(body["Items"]) || []
          http_exists = items.any? { |it| (it["Code"] || it["code"]).to_s.casecmp?(code) }
          Rails.logger.info("[Xero::InvoiceExportJob] HTTP fallback probe code=#{code.inspect} exists=#{http_exists}")
          return true if http_exists
        end
      rescue => e
        Rails.logger.warn("[Xero::InvoiceExportJob] HTTP fallback probe failed for code=#{code.inspect}: #{e.class}: #{e.message}")
      end

      false
    end
    private :item_exists?

    # Attempt to create the given item codes in Xero.
    # Uses the SDK first, then falls back to raw HTTP if the SDK returns 404/empty.
    def auto_create_items(accounting_api, tenant_id, codes, fallback_account_code)
      codes = Array(codes).compact.uniq
      return if codes.empty?

      # Build minimal valid payloads. If an account code is provided, include SalesDetails to satisfy org validation.
      items_payload = {
        items: codes.map do |code|
          item_hash = {
            code: code.to_s,
            name: code.to_s,        # use Code as Name if we don't have a friendlier label
            is_sold: true
          }
          if fallback_account_code.present?
            item_hash[:sales_details] = {
              unit_price: 0.0,
              account_code: fallback_account_code.to_s
            }
          end
          item_hash
        end
      }

      Rails.logger.info("[Xero::InvoiceExportJob] Attempting SDK create_items for #{codes.inspect}")
      begin
        resp = accounting_api.create_items(tenant_id, items_payload)
        created = Array(resp&.items).map { |it| it&.code }.compact
        Rails.logger.info("[Xero::InvoiceExportJob] SDK create_items created/echoed codes=#{created.inspect}")
        # If SDK says nothing created and some codes still missing, try HTTP fallback
        leftover = codes - created
        if leftover.any?
          Rails.logger.warn("[Xero::InvoiceExportJob] SDK create_items did not confirm for #{leftover.inspect}; trying HTTP fallback")
          leftover.each { |code| create_item_http(tenant_id, code, fallback_account_code) }
        end
        nil
      rescue XeroRuby::ApiError => e
        corr = (e.response_headers || {})["xero-correlation-id"] rescue nil
        status = e.respond_to?(:code) ? e.code : nil
        Rails.logger.error("[Xero::InvoiceExportJob] SDK create_items ApiError status=#{status} corr=#{corr} short_corr=#{short(corr)} body=#{e.response_body.to_s.presence || '(empty)'} — will try HTTP fallback for all.")
        # Fall back to HTTP for all
        codes.each { |code| create_item_http(tenant_id, code, fallback_account_code) }
      end
    end
    private :auto_create_items

    # Raw HTTP POST to create a single Item, working around SDK quirks.
    def create_item_http(tenant_id, code, fallback_account_code)
      token = XeroConnection.first&.access_token
      raise "missing access_token" if token.blank?

      url = "https://api.xero.com/api.xro/2.0/Items"
      payload = {
        "Items" => [
          {
            "Code" => code.to_s,
            "Name" => code.to_s,
            "IsSold" => true,
            "IsPurchased" => false
          }.tap do |h|
            if fallback_account_code.present?
              h["SalesDetails"] = {
                "UnitPrice" => 0.0,
                "AccountCode" => fallback_account_code.to_s
              }
            end
          end
        ]
      }

      Rails.logger.info("[Xero::InvoiceExportJob] HTTP create Item code=#{code.inspect} POST #{url}")
      resp = HTTParty.post(
        url,
        headers: {
          "Authorization" => "Bearer #{token}",
          "Xero-Tenant-Id" => tenant_id,
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        },
        body: payload.to_json
      )
      corr = resp.headers["xero-correlation-id"] rescue nil
      Rails.logger.info("[Xero::InvoiceExportJob] HTTP create Item code=#{code.inspect} status=#{resp.code} corr=#{corr} short_corr=#{short(corr)} bytes=#{resp.body.to_s.bytesize}")
      if resp.code.to_i >= 400
        Rails.logger.warn("[Xero::InvoiceExportJob] HTTP create Item failed for code=#{code.inspect}: status=#{resp.code} body=#{resp.body}")
      end
    rescue => e
      Rails.logger.warn("[Xero::InvoiceExportJob] HTTP create Item exception for code=#{code.inspect}: #{e.class}: #{e.message}")
    end
    private :create_item_http

    private

    def refresh_token(connection)
      client_id     = Rails.application.credentials.dig(:xero, :client_id)
      client_secret = Rails.application.credentials.dig(:xero, :client_secret)

      if client_id.blank? || client_secret.blank?
        Rails.logger.error("[Xero::InvoiceExportJob] Missing Xero client credentials; cannot refresh token.")
        return false
      end

      Rails.logger.info("[Xero::InvoiceExportJob] Refreshing access token… expires_at was #{connection.expires_at&.iso8601}")
      response = HTTParty.post(
        "https://identity.xero.com/connect/token",
        headers: { "Content-Type" => "application/x-www-form-urlencoded" },
        body:    { grant_type: "refresh_token", refresh_token: connection.refresh_token },
        basic_auth: { username: client_id, password: client_secret }
      )

      if response.success?
        data = response.parsed_response
        connection.update!(
          access_token:  data["access_token"],
          refresh_token: data["refresh_token"],
          expires_at:    Time.current + data["expires_in"].to_i.seconds
        )
        corr = response.headers["xero-correlation-id"] rescue nil
        Rails.logger.info("[Xero::InvoiceExportJob] Token refresh successful; new expires_at=#{connection.expires_at&.iso8601} corr=#{corr} short_corr=#{short(corr)}")
        true
      else
        status = response.code rescue nil
        corr   = response.headers["xero-correlation-id"] rescue nil
        Rails.logger.error("[Xero::InvoiceExportJob] Token refresh FAILED status=#{status} corr=#{corr} short_corr=#{short(corr)} body=#{response.body}")
        false
      end
    end
  end
end
