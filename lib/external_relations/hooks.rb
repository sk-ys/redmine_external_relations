module ExternalRelations
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context={})
      html = "<script type=\"text/javascript\">\n//<![CDATA[\n"
      html << "ExRels = { settings: #{create_ex_rels_settings_array(context).to_json} };"
      html << "\n//]]>\n</script>"
      return html
    end

    def create_ex_rels_settings_array(context)
      request = context[:request]
      settings = {
        host_name: request.host_with_port,
        app_name: Redmine::Utils.relative_url_root.gsub(%r{^\/}, ''),
        external_app_names: ExternalRelationApp.all(),
        message: {
          confirm_add_link: l(:message_confirm_add_link),
          confirm_break_link: l(:message_confirm_break_link),
          error_add_link: l(:message_error_add_link)
        }
      }
      return settings
    end

    def view_issues_show_description_bottom(context={})
      context[:ex_rels] = ExternalRelation.all
      context[:hook_caller].send(:render,
        {
          partial: '/hooks/external_relations/view_issues_show_description_bottom',
          locals: context
        })
    end

    def controller_issues_edit_after_save(context={})
      issue = context[:issue]
      request = context[:request]
      Thread.start do
        call_update_issue(issue.id, request)
      end
    end

    # todo: This method is dummy. This method does not exist in Redmine 4.0.0.
    def controller_issues_bulk_edit_after_save(context={})
      issue = context[:issue]
      request = context[:request]
      Thread.start do
        call_update_issue(issue.id, request)
      end
    end

    def controller_issues_edit_before_save(context={})
      context = block_update_done_ratio(context)
    end

    def  controller_issues_bulk_edit_before_save(context={})
      context = block_update_done_ratio(context)
    end

  private
    def call_update_issue(issue_id, request)  # todo: integrate similar features in external_relations_controller
      Rails.logger.info("#{Time.now} _ start _ call_update_issue[hook]")

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

      Rails.logger.info("#{Time.now} __ end __ call_update_issue[hook] #{response.code}")
    end

    def block_update_done_ratio(context)
      issue = context[:issue]

      if ExternalRelation.where({issue_to_id: issue.id, issue_to_app_id: 1}).count > 0
        issue_current = Issue.find(issue.id)
        if issue.done_ratio != issue_current.done_ratio
          issue.done_ratio = issue_current.done_ratio
          context[:issue] = issue
          Rails.logger.info(l(:message_done_ratio_is_not_updated))
        end
      end

      return context
    end
  end
end