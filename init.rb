require_dependency 'external_relations/hooks'
Redmine::Plugin.register :external_relations do
  name 'External Relations plugin'
  author 'sk-ys'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'https://github.com/sk-ys/redmine_external_relations'
  author_url 'https://github.com/sk-ys/'

  requires_redmine version_or_higher: '4.0.0'

  settings default: {
    er_external_app_name: '',
  }, partial: 'settings/external_relations/general'

  menu :admin_menu,
    :external_relations,
    { controller: 'external_relations', action: 'show' },
    :html => { :class => 'icon icon-settings'},
    :if => Proc.new { User.current.admin? }

  project_module :external_relations do
    permission :view_ex_rels, {
      external_relations: [:show],
      external_relation_items: [:show]
    }
    permission :create_ex_rels, {
      external_relations: [:show, :new, :create, :update_issue],
      external_relation_items: [:show, :new, :create]
    }
    permission :manage_ex_rels, {
      external_relations: [:show, :new, :create, :update_issue],
      external_relation_items: [:show, :new, :create, :destroy]
    }
  end
end

Rails.configuration.to_prepare do
  ExternalRelations::ExternalRelationsPatch.install
  ExternalRelations::BulkUpdateWithExrelsToIssuesControllerPatch.install
  ExternalRelations::DestroyWithExrelsToIssuesControllerPatch.install
end
