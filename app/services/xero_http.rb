# frozen_string_literal: true

require "net/http"
require "json"

class XeroHttp
  def self.get_json(url:, access_token:, tenant_id:)
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    req["Authorization"]  = "Bearer #{access_token}"
    req["xero-tenant-id"] = tenant_id
    req["Accept"]         = "application/json"

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
    corr = res["xero-correlation-id"]
    Rails.logger.info("XeroHttp GET #{uri} -> #{res.code} corr=#{corr}")

    [ res, corr, (JSON.parse(res.body) rescue {}) ]
  end
end
