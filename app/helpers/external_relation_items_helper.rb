module ExternalRelationItemsHelper
  def relative_app_name
    Redmine::Utils.relative_url_root.gsub(%r{^\/}, '')
  end

  def app_id_to_name(app_id)
    if app_id == 1
      app_name = relative_app_name()
    else
      app_name = ExternalRelationApp.find_by_id(app_id).app_name
    end
    app_name
  end

  def app_name_to_id(app_name)
    if app_name == relative_app_name()
      app_id = 1
    else
      app = ExternalRelationApp.find_by(app_name: app_name)
      if app.nil?
        app_id = 0
      else
        app_id = app.id
      end
    end
    app_id
  end

  def app_id_to_title(app_id)
    ExternalRelationApp.find_by_id(app_id).app_title
  end

  def get_table_from_another_app(app_name, params={}, symbolize=true)
    require 'json'
    require 'net/http'
    require 'uri'

    uri = URI(
      request.protocol + request.host +
      "/#{app_name}" + "/external_relations/items.json")
    uri.query = params.to_param if params.length > 0
    response = Net::HTTP.get_response(uri)

    if response.code == '200'
      return JSON.parse(response.body, symbolize_names: symbolize)
    else
      return nil
    end
  end

  def get_table_from_another_apps(params={}, symbolize=true)
    another_app_tables = {}
    app_names = ExternalRelationApp.all.map{
      |e| e.attributes.values
    }.transpose[1][1..-1]  # get array of app_name except for local
    app_names.each do |app_name|
      another_app_tables[app_name] = get_table_from_another_app(app_name, params, symbolize)
    end
    return another_app_tables
  end

  def abs_local_app_name(ex_rel_array)
    ex_rel_array.keys.each { |app_name|
      ex_rel_array[app_name].each { |items|
        items[:issue_from_app_name] = app_name if items[:issue_from_app_id] == 1
        items[:issue_to_app_name] = app_name if items[:issue_to_app_id] == 1
      }
    }
    return ex_rel_array
  end

  def exchange_app_id(hash, app_name)
    id = app_name_to_id(app_name)
    return hash.each {|item|
      if item[:issue_to_app_id] == 1
        item[:issue_to_app_id] = id
        item[:issue_to_app_name] = app_name
      end
      item[:issue_from_app_id] = 1  # local
    }
  end

  def merge_another_table_hash(table_base, table_another)
    table_new = table_base
    table_another.keys.each{ |app_name|
      table_new = table_new + exchange_app_id(table_another[app_name], app_name)
    }
    return table_new
  end

  def active_record_to_array_hash(active_record, symbolize=true)
    if symbolize
      return active_record.map{|e| e.attributes.symbolize_keys}
    else
      return active_record.map{|e| e.attributes}
    end
  end

  def check_table(table_another)
    logger.info(table_another)
    table_another.keys.each{ |app_name|
      return false if table_another[app_name].nil?
    }
    return true
  end

  def delete_item(ex_rel)
    issue_to_app_name = app_id_to_name(ex_rel.issue_to_app_id)
    issue_to_id = ex_rel.issue_to_id

    deleted = ex_rel.destroy

    if deleted
      # update done_ratio in link_to issues
      Thread.start do
        call_update_issue_done_ratios(issue_to_app_name, [issue_to_id])
      end
    end

    return deleted
  end

  def exrels_tabs
    tabs = []
    tabs << {
      :name => 'link_to',
      :label => :label_title_ex_rels_issue_to,
      :partial => 'issues/tabs/exrels_table_to'}
    tabs << {
      :name => 'link_from',
      :label => :label_title_ex_rels_issue_from,
      :partial => 'issues/tabs/exrels_table_from'}
    tabs
  end

  def link_to_break(ex_rel, data_type)
    link_to '',
      { controller: 'external_relation_items', action: :destroy,
        id: ex_rel[:id], ex_rel: ex_rel, data_type: data_type },
      method: :delete, remote: true, class: 'icon icon-link-break',
      data: { confirm: l(:text_are_you_sure) }, title: l(:label_link_break)
  end
end
