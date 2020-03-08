class ExternalRelationItemsController < ApplicationController
  layout 'admin'

  accept_api_auth :index, :show, :create, :update, :destroy
  before_action :find_ex_rel, except: [:index, :new, :create, :redraw_table]
  before_action :params_ex_rel, only: [:index, :create]
  before_action :params_ex_rel_require, only: [:create]
  before_action :require_admin, only: [:new, :show, :edit]
  before_action :require_admin, only: [:index, :create], if: :request_html?

  include ExternalRelationItemsHelper
  include ExternalRelationsHelper

  def index
    @ex_rels = ExternalRelation.where(@params_ex_rel)

    respond_to do |format|
      format.html {
        render
      }
      format.api {
        @ex_rels_with_app_name = ExternalRelation.where(@params_ex_rel).with_app_name()
        render json: @ex_rels_with_app_name
      }
    end
  end

  def new
    @ex_rel = ExternalRelation.new()
  end

  def create
    if check_circular_dependency(@params_ex_rel)
      saved = false
      @ex_rel = ExternalRelation.new()
      @ex_rel.errors.add :base, :taken
    else
      @ex_rel = ExternalRelation.new(@params_ex_rel)

      begin
        saved = @ex_rel.save
      rescue
        saved = false
        @ex_rel.errors.add :base, :taken
      end
    end

    if saved
      # update done_ratio in link_to issues
      Thread.start do
        call_update_issue_done_ratios(app_id_to_name(@ex_rel.issue_to_app_id), [@ex_rel.issue_to_id])
      end
    end

    @errors = @ex_rel.errors

    respond_to do |format|
      format.html {
        if request.xhr?
          if saved
            logger.info("format.html[xhr], saved")
            head :ok
          else
            logger.info("format.html[xhr], unsaved")
            head :not_found
          end
        else
          if saved
            logger.info("format.html, saved")
            flash[:notice] = l(:notice_successful_create)
            back_url = params[:back_url].to_s
            if back_url.present? && valid_url = validate_back_url(back_url)
              redirect_to(valid_url)
            else
              redirect_to({ controller: 'external_relations', action: 'show' })
            end
          else
            logger.info("format.html, unsaved")
            render action: 'new'
          end
        end
      }
      format.js {
        if saved
          if @data_type == "from"
            @issue_id = @ex_rel.issue_to_id
            @ex_rels = ExternalRelation.where("issue_to_id=#{@issue_id} and issue_to_app_id=1")
          elsif @data_type == "to"
            @issue_id = @ex_rel.issue_from_id
            @ex_rels = ExternalRelation.where("issue_from_id=#{@issue_id} and issue_from_app_id=1")
          else
            @issue_id = nil
            @ex_rels = ExternalRelation.all()
          end
          logger.info("format.js, saved")
        else
          logger.info("format.js, unsaved")
          render status: 400
        end
      }
      format.api {
        if saved
          logger.info("format.api, saved")
          head :ok
        else
          logger.info("format.api, unsaved")
          head :bad_request
        end
      }
    end
  end

  def redraw_table
    @errors = []
    params.require([:issue_id, :data_type])
    @issue_id = params[:issue_id]
    @data_type = params[:data_type]

    respond_to do |format|
      format.js {
        begin
          render_redraw_table()
        rescue => e
          render js: "alert('#{e}')"
        end
      }
    end
  end

  def update
    params.permit!
    @ex_rel.attributes = params[:ex_rel]
    begin
      saved = @ex_rel.save
    rescue
      saved = false
      @ex_rel.errors.add :base, :taken
    end

    respond_to do |format|
      format.html {
        unless saved
          flash[:error] = "Incorrect value."
          redirect_to({ action: 'show' })
        else
          redirect_back_or_default({ controller: 'external_relations', action: 'show' })
        end
      }
    end
  end

  def show
  end

  def edit
  end

  def destroy
    deleted = false
    project_to = find_project_by_issue_id(@ex_rel.issue_to_id)
    if project_to.present? && User.current.allowed_to?(:manage_ex_rels, project_to)
      deleted = delete_item(@ex_rel)
    end

    respond_to do |format|
      format.html {
        redirect_to({ controller: 'external_relations', action: 'show' })
      }
      format.api {
        if deleted
          render_api_ok
        else
          render_api_errors('Failed to delete item.')
        end
      }
      format.js {
        if deleted
          @data_type = "from"
          @issue_id = @ex_rel.issue_to_id
          begin
            render_redraw_table()
          rescue => e
            render js: "alert('#{e}')"
          end
        else
          render js: "alert('Error')"
        end
      }
    end
  end

private
  def find_ex_rel
    @ex_rel = ExternalRelation.find_by_id(params[:id])
    render_404 unless @ex_rel
  end

  def params_ex_rel
    params.permit!

    @data_type = ""

    if params[:ex_rel]
      @params_ex_rel = params[:ex_rel]
      @data_type = params[:data_type]
    elsif params[:ex_rel_from]
      @params_ex_rel = params[:ex_rel_from]
      @data_type = "from"
    elsif params[:ex_rel_to]
      @params_ex_rel = params[:ex_rel_to]
      @data_type = "to"
    else
      @params_ex_rel = params.permit(
        :id,
        :issue_from_id, :issue_from_app_id, :issue_from_app_name,
        :issue_to_id, :issue_to_app_id, :issue_to_app_name)
    end

    # app_name to app_id
    if @params_ex_rel[:issue_to_app_name]
      @params_ex_rel[:issue_to_app_id] = app_name_to_id(@params_ex_rel[:issue_to_app_name])
      @params_ex_rel.delete(:issue_to_app_name)
    end

    if @params_ex_rel[:issue_from_app_name]
      @params_ex_rel[:issue_from_app_id] = app_name_to_id(@params_ex_rel[:issue_from_app_name])
      @params_ex_rel.delete(:issue_from_app_name)
    end
  end

  def params_ex_rel_require
    if @data_type.present?
      if @data_type == "from"
        @params_ex_rel.require([:issue_to_id, :issue_to_app_id])
      else
        @params_ex_rel.require([:issue_from_id, :issue_from_app_id])
      end
    else
      @params_ex_rel.require(
        [
        :issue_from_id, :issue_from_app_id,
        :issue_to_id, :issue_to_app_id
        ])
    end
  end

  def check_circular_dependency(params)
    @circular_dependency = false

    begin
      @res = get_table_from_another_apps()
      @res[relative_app_name()] = active_record_to_array_hash(
          ExternalRelation.with_app_name,
          symbolize: true)
      @res = abs_local_app_name(@res)

      check_descendant(
        app_id_to_name(params[:issue_to_app_id].to_i), params[:issue_to_id].to_i,
        app_id_to_name(params[:issue_from_app_id].to_i), params[:issue_from_id].to_i)
    rescue
      return true
    end

    return @circular_dependency
  end

  def check_descendant(from_app_name, from_issue_id, my_app_name, my_issue_id, count_key=0)
    return if @circular_dependency

    target_item = []
    @res.keys.each { |app_name|
      target_item += @res[app_name].select { |item|
        item[:issue_from_app_name] == from_app_name &&
        item[:issue_from_id] == from_issue_id
      }
    }

    count_key_add = 0
    target_item.each { |item|
      to_app_name = item[:issue_to_app_name]
      to_issue_id = item[:issue_to_id]

      count_key_new = "#{count_key}#{count_key_add}"

      logger.info({
        "#{count_key_new}": {
          from: [from_app_name, from_issue_id],
          to: [to_app_name, to_issue_id],
          origin: [my_app_name, my_issue_id]
        }
      })

      if to_app_name == my_app_name && to_issue_id == my_issue_id
        @circular_dependency = true
        return
      else
        check_descendant(to_app_name, to_issue_id, my_app_name, my_issue_id, count_key_new)
      end

      count_key_add += 1
    }
  end

  def request_html?
    request.format.html?
  end

  def find_project_by_issue_id(issue_id)
    issue = Issue.find_by(id: issue_id)
    return nil if issue.nil?
    project = Project.find_by(id: issue.project_id)
    return project
  end

  def render_redraw_table()
    @errors = []
    if @data_type == "from"
      @ex_rels = ExternalRelation.where("issue_to_id=#{@issue_id} and issue_to_app_id=1")
    elsif @data_type == "to"
      @ex_rels = ExternalRelation.where("issue_from_id=#{@issue_id} and issue_from_app_id=1")
    end

    if @project.blank?
      @project = find_project_by_issue_id(@issue_id)
    end

    render action: :create
  end
end
