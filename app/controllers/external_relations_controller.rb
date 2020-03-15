class ExternalRelationsController < ApplicationController
  layout 'admin'

  accept_api_auth :issue_done_ratios, :update_issue_done_ratios, :update_issue, :delete_issue, :get_app_title
  before_action :require_admin, only: [:show]

  include ExternalRelationItemsHelper
  include ExternalRelationsHelper
  helper :external_relation_items

  def show
    @ex_rel_apps = ExternalRelationApp.all()
    @ex_rel_app = ExternalRelationApp.new()
    @ex_rels = ExternalRelation.all()
  end

  def update_issue
    params.require([:issue_id])
    issue_id = params[:issue_id]
    issue = Issue.find_by(id: issue_id)

    status = false
    use_thread = true
    respond_to do |format|
      format.api { use_thread = true }
      format.js { use_thread = false }
    end

    if issue.present?
      this_app_name = relative_app_name()
      ex_rels = ExternalRelation.where({issue_from_id: issue_id, issue_from_app_id: 1}).with_app_name()

      if ex_rels.present?
        logger.info("#{ex_rels.length} records found in local.")
        ex_rels_hash = active_record_to_array_hash(ex_rels, symbolize: true)
      else
        logger.info("record not found in local.")
        ex_rels_hash = []
      end

      begin
        table_another = get_table_from_another_apps({issue_from_id: issue_id, issue_from_app_name: this_app_name}, symbolize: true)
        ex_rels_hash = merge_another_table_hash(ex_rels_hash, table_another)

        logger.info("ex_rels: #{ex_rels_hash}")

        ExternalRelationApp.pluck(:app_name).each{ |app_name|
          issue_ids = ex_rels_hash.select{ |item|
            item[:issue_to_app_name] == app_name
          }.map{|e| e[:issue_to_id]}

          if issue_ids.present?
            app_name = this_app_name if app_name == "local"
            if use_thread
              Thread.start do
                call_update_issue_done_ratios(app_name, issue_ids)
              end
            else
              call_update_issue_done_ratios(app_name, issue_ids)
            end
          end
        }
        status = true
      rescue
        # do nothing
      end
    end

    respond_to do |format|
      format.api {
        if status
          render_api_ok
        else
          render_api_errors('Internal Server Error')
        end
      }
      format.js {
        if status
          redirect_to action: :redraw_table, controller: :external_relation_items,
            issue_id: issue_id,
            data_type: params[:data_type]
        else
          render js: "alert('#{l(:message_update_failed)}')"
        end
      }
    end
  end

  def delete_issue
    app_name = params[:app_name]
    app_id = app_name_to_id(app_name)
    issue_id = params[:issue_id]

    ex_rels = ExternalRelation.where({issue_from_id: issue_id, issue_from_app_id: app_id}).
              or(ExternalRelation.where({issue_to_id: issue_id, issue_to_app_id: app_id})).
              with_app_name()

    ex_rels.each { |ex_rel|
      delete_item(ex_rel)
    }

    respond_to do |format|
      format.api {
        render_api_ok
      }
    end
  end

  def get_issue_done_ratios
    done_ratios = Issue.where(id: params[:issue_ids]).pluck(:done_ratio)
    respond_to do |format|
      format.api {
        render json: done_ratios
      }
    end
  end

  def update_issue_done_ratios
    issues = Issue.where(id: params[:issue_ids])

    issues.each{ |issue|
      Thread.start do
        res = call_get_issue_done_ratios(issue.id)

        unless res.present?
          logger.info("Issue #{issue.id} unsaved. Item is not found.")
        else
          done_ratios = []
          res.keys.each{ |app_name|
            done_ratios += res[app_name]
          }

          done_ratio_mean = done_ratios.inject(:+) / done_ratios.length

          logger.info("Issue #{issue.id} done_ratio: #{issue.done_ratio} -> #{done_ratio_mean} (done_ratios: #{done_ratios})")

          # update done_ratio
          if done_ratio_mean != issue.done_ratio
            issue.done_ratio = done_ratio_mean
            saved = issue.save

            logger.info("Issue #{issue.id} saved. Status: #{saved}")

            if saved
              # update done_ratio of issues in link_to
              Thread.start do
                call_update_issue(issue.id)
              end
            else
              logger.info("Unsaved issue: #{issue.id}")
            end
          else
            logger.info("Issue #{issue.id} unsaved. Status not changed.")
          end
        end
      end
    }

    respond_to do |format|
      format.api {
        render_api_ok  # always return ok?
      }
    end
  end

  def get_app_title
    respond_to do |format|
      format.api {
        render json: Setting.app_title
      }
      format.js {
      }
    end
  end

  # ---------- private ----------
  private

  def call_get_issue_done_ratios(issue_id)
    logger.info("#{Time.now} + start + call_get_issue_done_ratios")

    issue_ids = {}
    done_ratios = {}
    ex_rels = ExternalRelation.where("issue_to_id=#{issue_id} and issue_to_app_id=1")

    if ex_rels.empty?
      return nil
    end

    ExternalRelationApp.all.each {|item|
      app_name = item.app_name
      app_name = relative_app_name() if app_name == "local"
      issue_ids[app_name] = ex_rels.where("issue_from_app_id=#{item.id}").pluck(:issue_from_id)
      if issue_ids[app_name].length > 0
        done_ratios[app_name] = call_get_issue_done_ratio(app_name, issue_ids[app_name])
      end
    }

    logger.info("#{Time.now} ++ end ++ call_get_issue_done_ratios")

    return done_ratios
  end

  def call_get_issue_done_ratio(app_name, issue_ids, symbolize=true)
    logger.info("#{Time.now} = start = call_get_issue_done_ratio")
    require 'json'
    require 'net/http'
    require 'uri'

    uri = URI(
      request.protocol + request.host +
      "/#{app_name}" + "/external_relations/issue_done_ratios.json")
    uri.query = {issue_ids: issue_ids}.to_param
    response = Net::HTTP.get_response(uri)

    logger.info("#{Time.now} == end == call_get_issue_done_ratio")

    if response.code == '200'
      return JSON.parse(response.body, symbolize_names: symbolize)
    else
      return nil
    end
  end
end
