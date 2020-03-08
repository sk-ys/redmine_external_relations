class ExternalRelationAppsController < ApplicationController
  layout 'admin'

  before_action :ex_rel_app_params, only: [:create, :update]
  before_action :find_ex_rel_app, except: [:index, :new, :create]
  before_action :check_editable, only: [:update, :destroy]
  before_action :get_app_title, only: [:create, :update]
  before_action :require_admin, if: :request_html?

  def index
    @ex_rel_apps = ExternalRelationApp.all()
    @ex_rel_app = ExternalRelationApp.new()
  end

  def new
    @ex_rel_app = ExternalRelationApp.new()
  end

  def create
    saved = false
    if @app_title.present?
      @ex_rel_app_params[:app_title] = @app_title if @ex_rel_app_params[:app_title] == ""
      @ex_rel_app = ExternalRelationApp.new(@ex_rel_app_params)
      begin
        saved = @ex_rel_app.save
      rescue
      end
    end

    @ex_rel_app.errors.add :base, :taken unless saved

    respond_to do |format|
      format.html {
        unless saved
          flash[:error] = "Incorrect value."
          redirect_back_or_default({ controller: 'external_relations', action: 'index' }, referer: true)
        else
          redirect_to({ controller: 'external_relations', action: 'show' })
        end
      }
      format.js {
        @ex_rel_apps = ExternalRelationApp.all()
      }
      format.api {
        if saved
          render controller: 'external_relations', :action => 'show', :status => :created
        else
          render_validation_errors(@ex_rel_app)
        end
      }
    end
  end

  def show
  end

  def edit
  end

  def update
    raise Unauthorized unless @ex_rel_app.editable?

    saved = false
    if @app_title.present?
      begin
        saved = @ex_rel_app.update(@ex_rel_app_params)
      rescue
      end
    end

    @ex_rel_app.errors.add :base, :taken unless saved

    respond_to do |format|
      format.html {
        unless saved
          flash[:error] = "Incorrect value."
        end
        redirect_back_or_default({ controller: 'external_relations', action: 'show' })
      }
    end
  end

  def destroy
    raise Unauthorized unless @ex_rel_app.deletable?
    @ex_rel_app.destroy

    respond_to do |format|
      format.html{
        redirect_to({ controller: 'external_relations', action: 'show' })
      }
    end
  end

private
  def find_ex_rel_app
    @ex_rel_app = ExternalRelationApp.find_by_id(params[:id])
    render_404 unless @ex_rel_app
  end

  def check_editable
    unless @ex_rel_app.editable?
      flash[:error] = "Can not edit local app name."
      redirect_back_or_default({ controller: 'external_relations', action: 'show' }, referer: true)
    end
  end

  def ex_rel_app_params
    @ex_rel_app_params = params.require(:ex_rel_app).permit(:app_name, :app_title)
  end

  def get_app_title
    require 'json'
    require 'net/http'
    require 'uri'

    app_name = params[:ex_rel_app][:app_name]

    if app_name == "local"
      @app_title = Setting.app_title
    else
      uri = URI(
        request.protocol + request.host +
        "/#{app_name}" + "/external_relations/app_title.json")
      response = Net::HTTP.get_response(uri)

      if response.code == '200'
        @app_title = response.body
      else
        @app_title = nil
      end
    end
  end

  def request_html?
    request.format.html?
  end
end
