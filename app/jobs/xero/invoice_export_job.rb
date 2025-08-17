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

      fallback_account_code = resolve_fallback_account_code(accounting_api, xero_tenant_id, connection)

      invoice_export.update(status: "processing")
      exported_count = 0
      Rails.logger.info("[Xero::InvoiceExportJob] Using tenant_id=#{xero_tenant_id} token_expires_at=#{connection.expires_at&.iso8601}")
      Rails.logger.info("[Xero::InvoiceExportJob] Fallback account code resolved to: #{fallback_account_code.presence || '(none)'}")

      lines_by_location = invoice_export.invoice_export_lines.includes(:location, :area, :timesheet).group_by(&:location)
      Rails.logger.info("[Xero::InvoiceExportJob] Grouped lines by location: #{lines_by_location.transform_values { |arr| arr.size }}")

      lines_by_location.each do |location, lines|
        begin
          contact_hash = ensure_contact_hash(accounting_api, xero_tenant_id, location.name)
          Rails.logger.info("[Xero::InvoiceExportJob] Using contact #{contact_hash[:contact_id] ? 'ContactID' : 'Name'} for location='#{location&.name}'")

          Rails.logger.info("[Xero::InvoiceExportJob] Building payload for location='#{location&.name}' lines=#{lines.size}")

          # === BEGIN travel supplement (create extra Travel line-items for timesheets with travel > 0) ===
          begin
            # Collect timesheets in this location batch
            timesheets_in_batch = lines.map(&:timesheet).compact.uniq
            travel_timesheets    = timesheets_in_batch.select { |ts| ts.travel.to_d > 0 }

            # Skip building duplicates when a line is already a Travel-area line for that timesheet
            travel_line_ts_ids_already_present =
              lines.select { |l| l.area&.name&.casecmp?("travel") }.map { |l| l.timesheet&.id }.compact.uniq

            travel_timesheets.reject! { |ts| travel_line_ts_ids_already_present.include?(ts.id) }

            # Find the Travel area for this location (case-insensitive)
            travel_area =
              begin
                Area.where(location_id: location&.id).find { |a| a.name.to_s.strip.casecmp?("travel") }
              rescue => e
                Rails.logger.warn("[Xero::InvoiceExportJob] Could not query Travel area for location='#{location&.name}': #{e.class}: #{e.message}")
                nil
              end

            @travel_item_line_items_extra = []
            @travel_account_line_items_extra = []

            if travel_timesheets.any?
              if travel_area.nil?
                Rails.logger.warn("[Xero::InvoiceExportJob] Travel timesheets present but no 'Travel' area found for location='#{location&.name}'. Skipping extra travel lines.")
              else
                mapped_travel_code =
                  if travel_area.respond_to?(:xero_item_code) && travel_area.xero_item_code.present?
                    travel_area.xero_item_code
                  else
                    travel_area.export_code
                  end

                travel_timesheets.each do |ts|
                  # Date string: "16 AUG 2025"
                  date_str =
                    begin
                      (ts.clock_in_at || Time.current).in_time_zone("Australia/Brisbane").to_date.strftime("%-d %^b %Y")
                    rescue
                      Time.current.in_time_zone("Australia/Brisbane").to_date.strftime("%-d %^b %Y")
                    end

                  desc = "Activity based transport #{date_str}"

                  qty = ts.travel.to_d
                  if qty <= 0
                    Rails.logger.debug("[Xero::InvoiceExportJob] Skipping zero/negative travel for timesheet_id=#{ts.id}")
                    next
                  end

                  # ItemCode mode: DO NOT set unit_amount so Xero uses the Item's default price
                  @travel_item_line_items_extra << {
                    item_code: mapped_travel_code,
                    description: desc,
                    quantity: qty,
                    tax_type: "NONE"
                    # no :unit_amount on purpose
                  }

                  # Fallback account mode (only used when ItemCode fails). Keep amount 0.0 and log.
                  @travel_account_line_items_extra << {
                    description: desc,
                    quantity: qty,
                    unit_amount: 0.0,
                    tax_type: "NONE",
                    account_code: fallback_account_code.presence
                  }

                  Rails.logger.info("[Xero::InvoiceExportJob] Added extra Travel line for timesheet_id=#{ts.id} location='#{location&.name}' qty=#{qty}")
                end
              end
            end
          rescue => e
            Rails.logger.error("[Xero::InvoiceExportJob] Travel supplement build error for location='#{location&.name}': #{e.class}: #{e.message}")
          end
          # === END travel supplement ===

          item_line_items = lines.map do |line|
            mapped_code = if line.area.respond_to?(:xero_item_code) && line.area.xero_item_code.present?
              line.area.xero_item_code
            else
              line.area.export_code
            end

            line_item = {
              item_code: mapped_code,
              description: line.description,
              tax_type: "NONE"
            }

            if line.area&.name&.downcase == "travel"
              # For Travel from a Travel-area line: quantity is travel hours, description fixed, no unit_amount.
              ts = line.timesheet
              date_str =
                begin
                  (ts.clock_in_at || Time.current).in_time_zone("Australia/Brisbane").to_date.strftime("%-d %^b %Y")
                rescue
                  Time.current.in_time_zone("Australia/Brisbane").to_date.strftime("%-d %^b %Y")
                end
              line_item[:description] = "Activity based transport #{date_str}"
              line_item[:quantity]    = ts.travel.to_d
              # IMPORTANT: do NOT set :unit_amount so Xero pulls price from Item Code
            else
              # Hours worked: keep existing behaviour (quantity = hours; no unit_amount here).
              line_item[:quantity] = line.timesheet.duration_in_hours
            end

            line_item
          end

          # Append the extra Travel line-items built from timesheets that had travel > 0 but no Travel line yet:
          if defined?(@travel_item_line_items_extra) && @travel_item_line_items_extra.present?
            Rails.logger.info("[Xero::InvoiceExportJob] Appending #{@travel_item_line_items_extra.size} extra Travel item-code lines for location='#{location&.name}'")
            item_line_items.concat(@travel_item_line_items_extra)
          end

          account_line_items = lines.map do |line|
            line_item = {
              description: line.description,
              tax_type: "NONE"
            }

            if line.area&.name&.downcase == "travel"
              ts = line.timesheet
              date_str =
                begin
                  (ts.clock_in_at || Time.current).in_time_zone("Australia/Brisbane").to_date.strftime("%-d %^b %Y")
                rescue
                  Time.current.in_time_zone("Australia/Brisbane").to_date.strftime("%-d %^b %Y")
                end
              line_item[:description] = "Activity based transport #{date_str}"
              line_item[:quantity]    = ts.travel.to_d
              line_item[:unit_amount] = 0.0  # In fallback account mode we cannot rely on Item pricing
            else
              line_item[:quantity]    = line.timesheet.duration_in_hours
              line_item[:unit_amount] = 0.0  # keep your existing fallback behaviour
            end

            line_item[:account_code] = fallback_account_code if fallback_account_code.present?
            line_item
          end

          # Append the extra Travel fallback lines too (only used when we switch to account mode)
          if defined?(@travel_account_line_items_extra) && @travel_account_line_items_extra.present?
            Rails.logger.info("[Xero::InvoiceExportJob] Appending #{@travel_account_line_items_extra.size} extra Travel account-mode lines for location='#{location&.name}'")
            account_line_items.concat(@travel_account_line_items_extra)
          end

          Rails.logger.warn("[Xero::InvoiceExportJob] No fallback account code available after auto-detect; set #{FALLBACK_ACCOUNT_ENV} or add a revenue account in Xero if you want account-mode retry.") if fallback_account_code.blank?

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

          item_codes = item_line_items.map { |li| li[:item_code] }.compact.uniq
          missing = item_codes.reject { |code| item_exists?(accounting_api, xero_tenant_id, code) }
          Rails.logger.info("[Xero::InvoiceExportJob] Preflight items: codes=#{item_codes.inspect} missing=#{missing.inspect}") unless item_codes.empty?

          if missing.any?
            Rails.logger.warn("[Xero::InvoiceExportJob] Missing item codes detected preflight: #{missing.inspect}")

            if ActiveModel::Type::Boolean.new.cast(ENV[AUTO_CREATE_ITEMS_ENV])
              Rails.logger.info("[Xero::InvoiceExportJob] #{AUTO_CREATE_ITEMS_ENV}=true — attempting to auto-create missing Items: #{missing.inspect}")
              begin
                auto_create_items(accounting_api, xero_tenant_id, missing, fallback_account_code)
              rescue => e_ac
                Rails.logger.error("[Xero::InvoiceExportJob] auto_create_items failed: #{e_ac.class}: #{e_ac.message}")
              end

              still_missing = missing.reject { |code| item_exists?(accounting_api, xero_tenant_id, code) }
              Rails.logger.info("[Xero::InvoiceExportJob] After auto-create, still missing: #{still_missing.inspect}")

              if still_missing.empty?
                Rails.logger.info("[Xero::InvoiceExportJob] Auto-created all missing items; proceeding with ItemCode invoice.")
              else
                missing = still_missing
              end
            end

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

          http_invoice_id = http_create_invoice(xero_tenant_id, contact_hash, item_line_items)
          if http_invoice_id.present?
            Rails.logger.info("[Xero::InvoiceExportJob] Created invoice_id=#{http_invoice_id} via HTTP fallback (items) for location='#{location&.name}'")
            lines.each { |line| line.update!(xero_invoice_id: http_invoice_id) }
            exported_count += 1
            next
          end

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
                http_invoice_id = http_create_invoice(xero_tenant_id, contact_hash, account_line_items)
                if http_invoice_id.present?
                  Rails.logger.info("[Xero::InvoiceExportJob] Created invoice_id=#{http_invoice_id} via HTTP fallback (account) for location='#{location&.name}'")
                  lines.each { |line| line.update!(xero_invoice_id: http_invoice_id) }
                  exported_count += 1
                  next
                end
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

      begin
        if defined?(XeroItem) && XeroItem.where(code: code).exists?
          Rails.logger.info("[Xero::InvoiceExportJob] Local cache reports item exists code=#{code.inspect}")
          return true
        end
      rescue => e
        Rails.logger.warn("[Xero::InvoiceExportJob] Local cache check failed for code=#{code.inspect}: #{e.class}: #{e.message}")
      end

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

      begin
        token = XeroConnection.first&.access_token
        raise "missing access_token" if token.blank?

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

    def auto_create_items(accounting_api, tenant_id, codes, fallback_account_code)
      codes = Array(codes).compact.uniq
      return if codes.empty?

      items_payload = {
        items: codes.map do |code|
          item_hash = {
            code: code.to_s,
            name: code.to_s,
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
        codes.each { |code| create_item_http(tenant_id, code, fallback_account_code) }
      end
    end
    private :auto_create_items

    def http_create_invoice(tenant_id, contact_hash, line_items_hashes)
      token = XeroConnection.first&.access_token
      raise "missing access_token" if token.blank?

      url = "https://api.xero.com/api.xro/2.0/Invoices"

      xero_line_items = line_items_hashes.map do |li|
        h = {}
        h["ItemCode"]    = li[:item_code].to_s if li.key?(:item_code) && li[:item_code].present?
        h["Description"] = li[:description].to_s if li.key?(:description)
        h["Quantity"]    = li[:quantity].to_f if li.key?(:quantity)
        h["UnitAmount"]  = li[:unit_amount].to_f if li.key?(:unit_amount)
        h["AccountCode"] = li[:account_code].to_s if li.key?(:account_code) && li[:account_code].present?
        h["TaxType"]     = li[:tax_type].to_s if li.key?(:tax_type)
        h
      end

      xero_contact =
        if contact_hash[:contact_id].present?
          { "ContactID" => contact_hash[:contact_id].to_s }
        else
          { "Name" => contact_hash[:name].to_s }
        end

      payload = {
        "Invoices" => [
          {
            "Type"       => "ACCREC",
            "Contact"    => xero_contact,
            "Date"       => Time.current.to_date.iso8601,
            "DueDate"    => (Time.current.to_date + 7.days).iso8601,
            "LineItems"  => xero_line_items,
            "Status"     => "DRAFT"
          }
        ]
      }

      headers = {
        "Authorization"  => "Bearer #{token}",
        "Xero-Tenant-Id" => tenant_id,
        "Content-Type"   => "application/json",
        "Accept"         => "application/json"
      }

      Rails.logger.info("[Xero::InvoiceExportJob] HTTP create Invoice POST #{url}")
      resp = HTTParty.post(url, headers: headers, body: payload.to_json)
      corr = resp.headers["xero-correlation-id"] rescue nil
      Rails.logger.info("[Xero::InvoiceExportJob] HTTP create Invoice status=#{resp.code} corr=#{corr} short_corr=#{short(corr)} bytes=#{resp.body.to_s.bytesize}")

      if resp.code.to_i == 200
        body = JSON.parse(resp.body) rescue {}
        inv  = Array(body["Invoices"]).first
        invoice_id = inv&.dig("InvoiceID")
        return invoice_id if invoice_id.present?
      end

      nil
    rescue => e
      Rails.logger.warn("[Xero::InvoiceExportJob] HTTP create Invoice exception: #{e.class}: #{e.message}")
      nil
    end

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
    private :http_create_invoice

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

    def resolve_fallback_account_code(accounting_api, tenant_id, connection)
      if connection.respond_to?(:sales_account_code) && connection.sales_account_code.present?
        Rails.logger.info("[Xero::InvoiceExportJob] Using connection.sales_account_code=#{connection.sales_account_code}")
        return connection.sales_account_code.to_s
      end

      if ENV[FALLBACK_ACCOUNT_ENV].present?
        Rails.logger.info("[Xero::InvoiceExportJob] Using ENV #{FALLBACK_ACCOUNT_ENV}=#{ENV[FALLBACK_ACCOUNT_ENV]}")
        return ENV[FALLBACK_ACCOUNT_ENV].to_s
      end

      Rails.logger.info("[Xero::InvoiceExportJob] Auto-detecting fallback account code via Accounts API…")
      accounts = []
      begin
        resp = accounting_api.get_accounts(tenant_id)
        accounts = Array(resp&.accounts)
      rescue XeroRuby::ApiError => e
        corr = (e.response_headers || {})["xero-correlation-id"] rescue nil
        status = e.respond_to?(:code) ? e.code : nil
        Rails.logger.warn("[Xero::InvoiceExportJob] SDK get_accounts ApiError status=#{status} corr=#{corr} short_corr=#{short(corr)} body=#{e.response_body.to_s.presence || '(empty)'}; trying HTTP fallback")
      end

      if accounts.blank?
        begin
          accounts = fetch_accounts_http(tenant_id)
        rescue => e
          Rails.logger.warn("[Xero::InvoiceExportJob] HTTP fallback get Accounts failed: #{e.class}: #{e.message}")
        end
      end

      chosen = nil
      if accounts.present?
        normalized = accounts.map do |a|
          if a.respond_to?(:code)
            { code: a.code.to_s, name: a.respond_to?(:name) ? a.name.to_s : (a["Name"] || a[:Name]).to_s, type: (a.respond_to?(:type) ? a.type.to_s : (a["Type"] || a[:Type]).to_s) }
          else
            { code: (a["Code"] || a[:Code]).to_s, name: (a["Name"] || a[:Name]).to_s, type: (a["Type"] || a[:Type]).to_s }
          end
        end

        chosen = normalized.find { |a| a[:code] == "200" && a[:type].casecmp?("REVENUE") }&.dig(:code)
        chosen ||= normalized.find { |a| a[:type].casecmp?("REVENUE") }&.dig(:code)
        chosen ||= normalized.find { |a| a[:code] == "200" }&.dig(:code)
        chosen ||= normalized.find { |a| a[:name].to_s.downcase.include?("sales") }&.dig(:code)
      end

      if chosen.present?
        Rails.logger.info("[Xero::InvoiceExportJob] Auto-detected revenue AccountCode=#{chosen}")
        chosen.to_s
      else
        Rails.logger.warn("[Xero::InvoiceExportJob] Could not auto-detect a revenue AccountCode; account-mode fallback will be disabled.")
        nil
      end
    end
    private :resolve_fallback_account_code

    def fetch_accounts_http(tenant_id)
      token = XeroConnection.first&.access_token
      raise "missing access_token" if token.blank?

      url = "https://api.xero.com/api.xro/2.0/Accounts"
      Rails.logger.info("[Xero::InvoiceExportJob] HTTP GET #{url}")
      resp = HTTParty.get(url, headers: {
        "Authorization" => "Bearer #{token}",
        "Xero-Tenant-Id" => tenant_id,
        "Accept" => "application/json"
      })
      corr = resp.headers["xero-correlation-id"] rescue nil
      Rails.logger.info("[Xero::InvoiceExportJob] HTTP Accounts status=#{resp.code} corr=#{corr} short_corr=#{short(corr)} bytes=#{resp.body.to_s.bytesize}")
      if resp.code.to_i == 200
        body = JSON.parse(resp.body) rescue {}
        Array(body["Accounts"])
      else
        []
      end
    end
    private :fetch_accounts_http
  end
end
