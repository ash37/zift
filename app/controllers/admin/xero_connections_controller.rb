# app/controllers/admin/xero_connections_controller.rb
require "ostruct"
class Admin::XeroConnectionsController < ApplicationController
  before_action :authenticate_user!
  # before_action :require_admin!

  def show
    @connection = XeroConnection.first

    # If we have pending tenants from OAuth, show a simple picker inline
    if params[:tenant_picker].present? && session[:xero_tenant_options].present? && session[:xero_pending_token].present?
      @tenant_options = Array(session[:xero_tenant_options])
      render inline: <<-ERB, layout: "application"
        <div class="bg-white p-6 rounded-lg shadow-md">
          <h1 class="text-2xl font-semibold mb-4">Choose Xero Organisation</h1>
          <p class="mb-4 text-gray-600">Select which organisation to connect.</p>
          <ul class="divide-y">
            <% @tenant_options.each do |t| %>
              <li class="py-3 flex items-center justify-between">
                <div>
                  <div class="font-medium"><%= t["tenantName"] %></div>
                  <div class="text-xs text-gray-500">ID: <code><%= t["tenantId"] %></code> • Type: <%= t["tenantType"] %></div>
                </div>
                <%= button_to "Connect", admin_xero_connection_path, method: :patch, params: { sync: 'select_tenant', tenant_id: t["tenantId"] }, class: "bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold py-2 px-3 rounded" %>
              </li>
            <% end %>
          </ul>
        </div>
      ERB
      return
    end

    # Diagnostics ivars (used by the admin view panel)
    @tenant_name = nil
    @token_scopes = @connection&.scopes
    @country_code = nil
    @payroll_region = nil
    @payroll_provisioned = nil
    @employee_count = nil
    @raw_employees_status = nil
    @raw_employees_len = nil

    return unless @connection

    tenant_id     = @connection.tenant_id
    access_token  = @connection.access_token

    # Resolve tenant name for sanity-checking the selected org
    begin
      conns_res = HTTParty.get(
        "https://api.xero.com/connections",
        headers: { "Authorization" => "Bearer #{access_token}" }
      )
      if conns_res.success?
        conn = Array(conns_res.parsed_response).find { |c| c["tenantId"] == tenant_id }
        @tenant_name = conn && conn["tenantName"]
      end
    rescue => _e
      # best-effort only
    end

    # Determine country/region and select payroll API
    @country_code = organisation_country_code(tenant_id, access_token)
    client = xero_api_client
    payroll = payroll_api_for(tenant_id, client) if client
    @payroll_region = payroll&.class&.name&.split("::")&.last

    if payroll
      if @country_code == "AU"
        # AU: rely on raw probe below to infer provisioning
        begin
          resp = payroll.get_employees(tenant_id)
          @employee_count = Array(resp&.employees).size
        rescue XeroRuby::ApiError => e
          @employee_count = 0 if e.code == 204
        end
      else
        # NZ/UK: probe provisioning via settings
        begin
          settings = payroll.get_settings(tenant_id)
          @payroll_provisioned = settings&.respond_to?(:settings) ? settings.settings.present? : true
        rescue XeroRuby::ApiError => e
          @payroll_provisioned = (e.code != 404)
        end
        begin
          resp = payroll.get_employees(tenant_id)
          @employee_count = Array(resp&.employees).size
        rescue XeroRuby::ApiError => e
          @employee_count = 0 if e.code == 204
        end
      end
    end

    # Raw AU probe (bypasses SDK) to expose HTTP status/body size
    if @country_code == "AU"
      begin
        raw = HTTParty.get(
          "https://api.xero.com/payroll.xro/1.0/Employees?pagesize=1",
          headers: {
            "Authorization"  => "Bearer #{access_token}",
            "Xero-Tenant-Id" => tenant_id,
            "Accept"         => "application/json"
          }
        )
        @raw_employees_status = raw.code
        @raw_employees_len    = raw.body.to_s.bytesize
        Rails.logger.info("Raw AU probe Employees?pagesize=1 -> status=#{@raw_employees_status}, bytes=#{@raw_employees_len}")
        @payroll_provisioned = true if raw.code == 200
      rescue => _e
        # ignore
      end
    end
  end

  def new
    client_id    = Rails.application.credentials.xero[:client_id]
    redirect_uri = callback_admin_xero_connection_url

    # --- THIS IS THE FIX ---
    # Added 'accounting.contacts' and 'accounting.transactions' for invoicing.
    scopes = "offline_access openid profile email accounting.settings accounting.contacts accounting.transactions payroll.employees payroll.timesheets payroll.settings"

    # CSRF state
    state = SecureRandom.hex(16)
    session[:xero_oauth_state] = state

    Rails.logger.info("SCOPES from #{__FILE__}:#{__LINE__} => #{scopes}")
    Rails.logger.info("Xero redirect_uri => #{redirect_uri}")
    Rails.logger.info("XERO_SCOPES => #{scopes}")

    # Build authorize URL safely
    q = URI.encode_www_form(
      response_type: "code",
      client_id:     client_id,
      redirect_uri:  redirect_uri,
      scope:         scopes,
      state:         state,
      prompt:        "consent"
    )
    auth_url = "https://login.xero.com/identity/connect/authorize?#{q}"
    redirect_to auth_url, allow_other_host: true
  end

  def callback
    # Validate CSRF state
    if params[:state].blank? || params[:state] != session.delete(:xero_oauth_state)
      return redirect_to admin_xero_connection_path, alert: "Invalid OAuth state. Please try connecting again."
    end

    client_id     = Rails.application.credentials.xero[:client_id]
    client_secret = Rails.application.credentials.xero[:client_secret]
    redirect_uri  = callback_admin_xero_connection_url

    token_resp = HTTParty.post(
      "https://identity.xero.com/connect/token",
      headers: { "Content-Type" => "application/x-www-form-urlencoded" },
      body: {
        grant_type:   "authorization_code",
        code:         params[:code],
        redirect_uri: redirect_uri
      },
      basic_auth: { username: client_id, password: client_secret }
    )

    unless token_resp.success?
      return redirect_to admin_xero_connection_path,
                         alert: "Failed to connect to Xero. Error: #{token_resp.body}"
    end

    token         = token_resp.parsed_response
    access_token  = token["access_token"]
    refresh_token = token["refresh_token"]
    expires_at    = Time.current + token["expires_in"].to_i.seconds

    # Fetch all connections and pick a tenant deterministically
    conns_res = HTTParty.get(
      "https://api.xero.com/connections",
      headers: { "Authorization" => "Bearer #{access_token}" }
    )
    unless conns_res.success?
      return redirect_to admin_xero_connection_path,
                         alert: "Connected, but couldn't list tenants (#{conns_res.code}). Please try again."
    end

    connections = conns_res.parsed_response # [{ "tenantId", "tenantName", "tenantType", ... }, ...]

    # If a tenant was explicitly provided in params, use it
    if params[:tenant_id].present?
      preferred = connections.find { |c| c["tenantId"] == params[:tenant_id] }
      unless preferred
        return redirect_to admin_xero_connection_path, alert: "The selected tenant could not be found for this user."
      end
    else
      # If multiple tenants exist, redirect to a simple picker
      if connections.is_a?(Array) && connections.size > 1
        session[:xero_pending_token] = {
          access_token:  access_token,
          refresh_token: refresh_token,
          expires_at:    expires_at.iso8601,
          scope:         token["scope"]
        }
        session[:xero_tenant_options] = connections
        return redirect_to admin_xero_connection_path(tenant_picker: 1), notice: "Choose a Xero organisation to connect."
      end
      preferred = connections.first
      unless preferred
        return redirect_to admin_xero_connection_path, alert: "No Xero tenants available for this user."
      end
    end

    # Persist (replace old)
    XeroConnection.destroy_all
    XeroConnection.create!(
      tenant_id:     preferred["tenantId"],
      access_token:  access_token,
      refresh_token: refresh_token,
      scopes:        token["scope"],
      expires_at:    expires_at
    )

    redirect_to admin_xero_connection_path, notice: "Successfully connected to Xero!"
  end

  def update
    case params[:sync]
    when "employees"      then sync_employees
    when "pay_items"      then sync_pay_items
    when "invoice_items"  then sync_invoice_items
    when "select_tenant"  then select_tenant
    else redirect_to admin_xero_connection_path, alert: "Invalid sync action."
    end
  end

  def destroy
    XeroConnection.destroy_all
    redirect_to admin_xero_connection_path, notice: "Disconnected from Xero."
  end

  def edit_user_mappings
    client = xero_api_client
    return unless client

    tenant_id = XeroConnection.first.tenant_id
    api = payroll_api_for(tenant_id, client)

    @users = User.where.not(role: nil).order(:name)
    employees_hashes = []

    begin
      Rails.logger.info("Calling API: #{api.class}.get_employees ...")
      resp = api.get_employees(tenant_id)
      employees_hashes = Array(resp&.employees)
      Rails.logger.info("SDK employees OK count=#{employees_hashes.size}")
    rescue XeroRuby::ApiError => e
      code    = (e.respond_to?(:code) ? e.code : nil)
      headers = (e.respond_to?(:response_headers) ? e.response_headers : {}) || {}
      corr    = headers["xero-correlation-id"] || headers["Xero-Correlation-Id"]
      Rails.logger.warn("Xero: get_employees failed code=#{code} corr=#{corr} hdrs=#{headers.inspect}")

      if code.to_i == 404
        access_token = XeroConnection.first.access_token
        url = "https://api.xero.com/payroll.xro/1.0/Employees?pagesize=200"

        if defined?(XeroHttp)
          res, rcorr, json = XeroHttp.get_json(url: url, access_token: access_token, tenant_id: tenant_id)
          Rails.logger.info("Raw AU probe Employees?pagesize=200 -> status=#{res.code} bytes=#{res.body&.bytesize || 0}")
          if res.code.to_i == 200 && json["Employees"].is_a?(Array)
            employees_hashes = json["Employees"]
            Rails.logger.info("Xero: Raw employees OK count=#{employees_hashes.size}")
          else
            Rails.logger.warn("Xero: Raw employees GET failed #{res.code} corr=#{rcorr}")
          end
        else
          raw = HTTParty.get(
            url,
            headers: { "Authorization" => "Bearer #{access_token}", "Xero-Tenant-Id" => tenant_id, "Accept" => "application/json" }
          )
          Rails.logger.info("Raw AU probe Employees?pagesize=200 -> status=#{raw.code} bytes=#{raw.body.to_s.bytesize}")
          if raw.code.to_i == 200 && raw.body.present?
            begin
              parsed = JSON.parse(raw.body)
              employees_hashes = parsed["Employees"].is_a?(Array) ? parsed["Employees"] : []
              Rails.logger.info("Xero: Raw employees OK count=#{employees_hashes.size}")
            rescue JSON::ParserError
              Rails.logger.warn("Raw AU employees response was not valid JSON")
            end
          end
        end
      elsif [ 401, 403 ].include?(code.to_i)
        redirect_to(admin_xero_connection_path, alert: "Could not fetch employees from Xero (#{code}). Please reconnect. Corr: #{corr}") and return
      else
        redirect_to(admin_xero_connection_path, alert: "Could not fetch employees from Xero (#{code}). Corr: #{corr}.") and return
      end
    end

    # **THE FIX IS HERE**
    # Convert the array of hashes into an array of OpenStruct objects
    # so the view can use dot notation (e.g., employee.first_name).
    @xero_employees = employees_hashes.map do |hash|
      OpenStruct.new(
        employee_id: hash["EmployeeID"],
        first_name: hash["FirstName"],
        last_name: hash["LastName"]
      )
    end
  end

  def update_user_mappings
    mappings = params.require(:mappings)
    mappings.each do |user_id, xero_employee_id|
      user = User.find(user_id)
      user.update_column(:xero_employee_id, xero_employee_id.presence) # Use presence to save nil if dropdown is blank
    end
    redirect_to admin_xero_connection_path, notice: "User mappings have been updated."
  end

  private

  def xero_api_client
    connection = XeroConnection.first
    return nil unless connection

    if connection.expires_at <= Time.current + 5.minutes
      client_id     = Rails.application.credentials.xero[:client_id]
      client_secret = Rails.application.credentials.xero[:client_secret]
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
      else
        redirect_to admin_xero_connection_path, alert: "Could not refresh Xero token. Please reconnect."
        return nil
      end
    end

    XeroRuby.configure do |config|
      config.access_token = connection.access_token
      config.debugging    = Rails.env.development?
    end

    client = XeroRuby::ApiClient.new
    client.default_headers ||= {}
    client.default_headers["Accept"] = "application/json"
    client
  end

  def organisation_country_code(tenant_id, access_token)
    res = HTTParty.get(
      "https://api.xero.com/api.xro/2.0/Organisation",
      headers: { "Authorization" => "Bearer #{access_token}", "Xero-Tenant-Id" => tenant_id, "Accept" => "application/json" }
    )
    Rails.logger.info("GET /api.xro/2.0/Organisation -> #{res.code}")
    return res.parsed_response.dig("Organisations", 0, "CountryCode") if res.code == 200
    nil
  end

  def payroll_api_for(tenant_id, api_client)
    connection   = XeroConnection.first or return nil
    access_token = connection.access_token
    override = ENV["XERO_PAYROLL_REGION"].to_s.strip.upcase
    if override.present?
      Rails.logger.info("XERO_PAYROLL_REGION override => #{override}")
      case override
      when "AU" then return XeroRuby::PayrollAuApi.new(api_client)
      when "NZ" then return XeroRuby::PayrollNzApi.new(api_client)
      when "UK", "GB" then return XeroRuby::PayrollUkApi.new(api_client)
      else
        Rails.logger.warn("Unknown XERO_PAYROLL_REGION '#{override}', falling back to auto-detect")
      end
    end

    cc = organisation_country_code(tenant_id, access_token)
    Rails.logger.info("Xero tenant CountryCode => #{cc.inspect}")
    case cc
    when "AU" then return XeroRuby::PayrollAuApi.new(api_client)
    when "NZ" then return XeroRuby::PayrollNzApi.new(api_client)
    when "GB" then return XeroRuby::PayrollUkApi.new(api_client)
    end

    [ XeroRuby::PayrollAuApi, XeroRuby::PayrollNzApi, XeroRuby::PayrollUkApi ].each do |klass|
      api = klass.new(api_client)
      begin
        case klass.name
        when "XeroRuby::PayrollAuApi"
          res = HTTParty.get(
            "https://api.xero.com/payroll.xro/1.0/Employees?pagesize=1",
            headers: { "Authorization" => "Bearer #{access_token}", "Xero-Tenant-Id" => tenant_id, "Accept" => "application/json" }
          )
          if res.code == 200
            Rails.logger.info("Payroll API fallback selected: #{klass.name}")
            return api
          elsif res.code == 404
          else
            raise XeroRuby::ApiError.new(code: res.code, response_body: res.body)
          end
        else
          api.get_settings(tenant_id)
          Rails.logger.info("Payroll API fallback selected: #{klass.name}")
          return api
        end
      rescue XeroRuby::ApiError => e
        raise e unless e.code == 404
      end
    end
    nil
  end

  def sync_employees
    client = xero_api_client
    return unless client
    xero_tenant_id = XeroConnection.first.tenant_id
    payroll = payroll_api_for(xero_tenant_id, client)
    unless payroll
      return redirect_to admin_xero_connection_path, alert: "Payroll not available for this tenant."
    end
    is_au = payroll.is_a?(XeroRuby::PayrollAuApi)
    employees = []
    if is_au
      Rails.logger.info("AU region detected – using authoritative raw Payroll v1 employees fetch...")
      raw = HTTParty.get(
        "https://api.xero.com/payroll.xro/1.0/Employees",
        headers: { "Authorization" => "Bearer #{XeroConnection.first.access_token}", "Xero-Tenant-Id" => xero_tenant_id, "Accept" => "application/json" }
      )
      ct = raw.headers && raw.headers["content-type"]
      Rails.logger.info("Raw AU fetch status=#{raw.code}, content-type=#{ct}, bytes=#{raw.body.to_s.bytesize}")
      if raw.code == 200 && raw.body.present?
        begin
          obj = JSON.parse(raw.body)
          items = Array(obj["Employees"] || obj["employees"])
          employees = items.map do |h|
            OpenStruct.new(
              employee_id: h["EmployeeID"] || h["employeeId"] || h["employee_id"],
              email:       h["Email"]      || h["email"]      || h["email_address"],
              first_name:  h["FirstName"]  || h["firstName"]  || h["first_name"],
              last_name:   h["LastName"]   || h["lastName"]   || h["last_name"]
            )
          end
        rescue JSON::ParserError
          Rails.logger.warn("Raw AU employees response was not valid JSON")
          employees = []
        end
      else
        Rails.logger.info("Raw AU fetch yielded no data – falling back to SDK get_employees")
        begin
          resp = payroll.get_employees(xero_tenant_id)
          employees = Array(resp&.employees)
        rescue XeroRuby::ApiError => e
          if e.code == 204
            Rails.logger.info("SDK get_employees returned 204 No Content; treating as zero employees.")
            employees = []
          else
            raise
          end
        end
      end
    else
      Rails.logger.info("Calling API: #{payroll.class}.get_employees ...")
      begin
        resp = payroll.get_employees(xero_tenant_id)
        employees = Array(resp&.employees)
      rescue XeroRuby::ApiError => e
        if e.code == 204
          Rails.logger.info("get_employees returned 204 No Content; treating as zero employees.")
          employees = []
        else
          raise
        end
      end
    end

    Rails.logger.info("Employees fetched (post-branch): count=#{employees.size}")
    if employees.any?
      updated_count = 0
      with_email = 0
      employees.each do |xe|
        email = xe.email.to_s.strip
        next if email.blank?
        with_email += 1
        if (user = User.find_by("lower(email) = ?", email.downcase))
          updated_count += 1 if user.update(xero_employee_id: xe.employee_id)
        end
      end
      redirect_to admin_xero_connection_path, notice: "Sync complete. Found #{employees.count} employees (#{with_email} with emails), updated #{updated_count} users by email."
    else
      begin
        settings = payroll.get_settings(xero_tenant_id)
        provisioned = settings&.settings.present?
      rescue XeroRuby::ApiError => e
        provisioned = (e.code != 404)
      end
      probe = nil
      if defined?(@raw_employees_status) && @raw_employees_status
        probe = " (raw AU probe HTTP #{@raw_employees_status}, bytes #{(@raw_employees_len || 0)})"
      end
      message = provisioned ? "Sync complete. No active employees found in Xero#{probe}." : "Payroll appears not provisioned for this tenant or you lack permissions#{probe}."
      redirect_to admin_xero_connection_path, notice: message
    end

  rescue XeroRuby::ApiError => e
    msg = case e.code
    when 401 then "Error syncing employees: 401 Unauthorized. Please reconnect."
    when 404 then "Error syncing employees: 404 Not Found. Likely wrong payroll region for this tenant or payroll not provisioned."
    else "Error syncing employees: #{e.code} #{e.message}"
    end
    redirect_to admin_xero_connection_path, alert: msg
  end

  def select_tenant
    opts = session[:xero_tenant_options]
    tok  = session[:xero_pending_token]
    unless opts && tok
      return redirect_to admin_xero_connection_path, alert: "No pending Xero connection found. Please connect again."
    end
    tenant_id = params[:tenant_id].to_s
    chosen = Array(opts).find { |c| c["tenantId"] == tenant_id }
    unless chosen
      return redirect_to admin_xero_connection_path, alert: "Selected tenant is not available."
    end
    XeroConnection.destroy_all
    XeroConnection.create!(
      tenant_id:     chosen["tenantId"],
      access_token:  tok[:access_token],
      refresh_token: tok[:refresh_token],
      scopes:        tok[:scope],
      expires_at:    Time.iso8601(tok[:expires_at])
    )
    session.delete(:xero_tenant_options)
    session.delete(:xero_pending_token)
    redirect_to admin_xero_connection_path, notice: "Connected to #{chosen["tenantName"]}."
  end

  def sync_pay_items
    client = xero_api_client
    return unless client
    xero_tenant_id = XeroConnection.first.tenant_id
    payroll = payroll_api_for(xero_tenant_id, client)
    unless payroll
      return redirect_to admin_xero_connection_path, alert: "Payroll not available for this tenant (not provisioned or insufficient permissions)."
    end
    Rails.logger.info("Calling API: #{payroll.class} (pay items) ...")
    pay_items = []
    if payroll.is_a?(XeroRuby::PayrollAuApi)
      headers = { "Authorization" => "Bearer #{XeroConnection.first.access_token}", "Xero-Tenant-Id" => xero_tenant_id, "Accept" => "application/json" }
      raw = HTTParty.get("https://api.xero.com/payroll.xro/1.0/PayItems", headers: headers)
      Rails.logger.info("Raw AU PayItems status=#{raw.code}, bytes=#{raw.body.to_s.bytesize}")
      parsed = nil
      if raw.code == 200 && raw.body.present?
        begin
          parsed = JSON.parse(raw.body)
        rescue JSON::ParserError
          Rails.logger.warn("Raw AU PayItems response was not valid JSON")
        end
      end
      if parsed
        container = parsed["PayItems"] || parsed["payItems"] || {}
        earnings  = container["EarningsRates"] || container["earningsRates"] || []
        if earnings.is_a?(Array) && earnings.any?
          pay_items = earnings.map do |er|
            { id: er["EarningsRateID"] || er["earningsRateID"] || er["EarningsRateId"] || er["earningsRateId"], name: er["Name"] || er["name"] }
          end
        end
      end
      if pay_items.empty?
        raw2 = HTTParty.get("https://api.xero.com/payroll.xro/1.0/EarningsRates", headers: headers)
        Rails.logger.info("Raw AU EarningsRates status=#{raw2.code}, bytes=#{raw2.body.to_s.bytesize}")
        if raw2.code == 200 && raw2.body.present?
          begin
            parsed2 = JSON.parse(raw2.body)
            list = parsed2["EarningsRates"] || parsed2["earningsRates"] || []
            if list.is_a?(Array)
              pay_items = list.map { |er| { id: er["EarningsRateID"] || er["earningsRateID"], name: er["Name"] || er["name"] } }
            end
          rescue JSON::ParserError
            Rails.logger.warn("Raw AU EarningsRates response was not valid JSON")
          end
        end
      end
    else
      begin
        settings = payroll.get_settings(xero_tenant_id)
        container = settings.settings&.pay_items
        earnings  = container&.earnings_rates || []
        pay_items = earnings.map { |er| { id: er.earnings_rate_id, name: er.name } }
      rescue XeroRuby::ApiError => e
        if e.code == 204
          pay_items = []
        else
          raise
        end
      end
    end
    Rails.logger.info("Pay items fetched: count=#{pay_items.size}")
    if pay_items.any?
      pay_items.each do |er|
        next if er[:id].blank?
        ShiftType.find_or_initialize_by(xero_earnings_rate_id: er[:id]).update(name: er[:name].presence || "(Unnamed earnings rate)")
      end
      redirect_to admin_xero_connection_path, notice: "Successfully synced #{pay_items.count} pay items."
    else
      redirect_to admin_xero_connection_path, notice: "Sync complete. No pay items found."
    end
  rescue XeroRuby::ApiError => e
    msg = case e.code
    when 401 then "Error syncing pay items: 401 Unauthorized. Please reconnect."
    when 404 then "Error syncing pay items: 404 Not Found. Likely wrong payroll region for this tenant or payroll not provisioned."
    else "Error syncing pay items: #{e.code} #{e.message}"
    end
    redirect_to admin_xero_connection_path, alert: msg
  end

  def sync_invoice_items
    client = xero_api_client
    return unless client

    connection = XeroConnection.first
    unless connection
      redirect_to admin_xero_connection_path, alert: "No Xero connection found. Please connect first." and return
    end

    tenant_id  = connection.tenant_id
    accounting = XeroRuby::AccountingApi.new(client)

    created = 0
    updated = 0
    page    = 1

    begin
      loop do
        Rails.logger.info "Calling API: AccountingApi.get_items page=#{page} ..."
        resp = accounting.get_items(tenant_id, { page: page })

        # Normalize response to an array of item objects/hashes
        batch =
          if resp.respond_to?(:items)
            Array(resp.items)
          elsif resp.is_a?(Hash)
            Array(resp["Items"] || resp["items"])
          else
            []
          end

        break if batch.blank?

        batch.each do |it|
          # Extract fields defensively for SDK objects or hashes
          xero_item_id = it.respond_to?(:item_id) ? it.item_id : (it["ItemID"] || it["ItemId"] || it["itemId"])
          code         = it.respond_to?(:code)    ? it.code    : (it["Code"]   || it["code"])
          name         = it.respond_to?(:name)    ? it.name    : (it["Name"]   || it["name"])
          description  = it.respond_to?(:description) ? it.description : (it["Description"] || it["description"])
          is_sold      = it.respond_to?(:is_sold) ? it.is_sold : it["IsSold"] || it["isSold"]
          is_tracked   = it.respond_to?(:is_tracked_as_inventory) ? it.is_tracked_as_inventory : (it["IsTrackedAsInventory"] || it["isTrackedAsInventory"])

          # Prefer unique match on xero_item_id if we have it, otherwise fall back to code
          rec =
            if xero_item_id.present? && XeroItem.column_names.include?("xero_item_id")
              XeroItem.find_or_initialize_by(xero_item_id: xero_item_id)
            else
              # last resort: use code as identifier
              identifier = code.presence || name # avoid totally blank keys
              next if identifier.blank?
              XeroItem.find_or_initialize_by(code: identifier)
            end

          # Assign attributes and count created/updated
          was_new = rec.new_record?
          rec.code        = code        if code.present?
          rec.name        = name        if name.present?
          rec.description = description if rec.respond_to?(:description)
          rec.is_sold     = is_sold     if rec.respond_to?(:is_sold)
          if rec.respond_to?(:is_tracked_as_inventory)
            rec.is_tracked_as_inventory = is_tracked
          end

          # If we matched by code but model has xero_item_id column, set it
          if xero_item_id.present? && rec.respond_to?(:xero_item_id) && rec.xero_item_id.blank?
            rec.xero_item_id = xero_item_id
          end

          if rec.changed?
            rec.save!
            was_new ? created += 1 : updated += 1
          end
        end

        # stop when the returned page is smaller than the typical page size
        break if batch.size < 100
        page += 1
      end

      if created.zero? && updated.zero?
        flash[:alert] = "Sync finished but no invoice items were returned from Xero."
      else
        flash[:notice] = "Synced Xero invoice items: #{created} created, #{updated} updated."
      end
      redirect_to admin_xero_connection_path

    rescue XeroRuby::ApiError => e
      code    = (e.respond_to?(:code) ? e.code : nil)
      headers = (e.respond_to?(:response_headers) ? e.response_headers : {}) || {}
      corr    = headers["xero-correlation-id"] || headers["Xero-Correlation-Id"]

      msg =
        case code
        when 401 then "Error syncing invoice items: 401 Unauthorized. Please reconnect."
        when 403 then "Error syncing invoice items: 403 Forbidden. Check Xero scopes for items (accounting.settings.read)."
        when 404 then "Error syncing invoice items: 404 Not Found."
        else          "Error syncing invoice items: #{code} #{e.message}"
        end

      redirect_to admin_xero_connection_path, alert: [ msg, (corr ? "Corr: #{corr}" : nil) ].compact.join(" ")
    end
  end
end
