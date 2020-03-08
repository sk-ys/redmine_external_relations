module ExternalRelationsHelper
  def call_update_issue(issue_id)  # todo: integrate similar features in hooks
    logger.info("#{Time.now} _ start _ call_update_issue[controller]")

    require 'json'
    require 'net/http'
    require 'uri'

    this_app_name = Redmine::Utils.relative_url_root.gsub(%r{^\/}, '')

    uri = URI(
      request.protocol + request.host +
      "/#{this_app_name}" + "/external_relations/issue.json")
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Patch.new(uri.path)
    req.set_form_data({issue_id: issue_id})
    response = http.request(req)

    logger.info("#{Time.now} __ end __ call_update_issue[controller] #{response.code}")
  end

  def call_delete_issue(issue_id)
    logger.info("#{Time.now} | start | call_delete_issue[controller]")

    require 'json'
    require 'net/http'
    require 'uri'

    this_app_name = Redmine::Utils.relative_url_root.gsub(%r{^\/}, '')

    response_codes = {}

    ExternalRelationApp.all.each {|item|
      app_name = item.app_name
      app_name = this_app_name if app_name == "local"

      uri = URI(
        request.protocol + request.host +
        "/#{app_name}" + "/external_relations/issue.json")
      http = Net::HTTP.new(uri.host, uri.port)
      req = Net::HTTP::Delete.new(uri.path)
      req.set_form_data({app_name: this_app_name, issue_id: issue_id})
      response = http.request(req)
      response_codes[app_name] = response.code
    }

    logger.info("#{Time.now} || end || call_delete_issue[controller] #{response_codes}")
  end

  def call_update_issue_done_ratios(app_name, issue_ids, symbolize=true)
    logger.info("#{Time.now} - start - call_update_issue_done_ratios app_name: #{app_name}, issue_ids: #{issue_ids}")

    require 'json'
    require 'net/http'
    require 'uri'

    uri = URI(
      request.protocol + request.host +
      "/#{app_name}" + "/external_relations/issue_done_ratios.json")
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Patch.new(uri.path)
    req.set_form_data({"issue_ids[]": issue_ids})
    response = http.request(req)

    logger.info("#{Time.now} -- end -- call_update_issue_done_ratios #{response.code}")
  end
end
