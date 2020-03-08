# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  resource :external_relations, only: [:show] do
    resources :apps, controller: :external_relation_apps
    resources :items, except: [:edit], controller: :external_relation_items
    patch "/redraw_table", to: "external_relation_items#redraw_table", constraints: {format: /js/}
    patch "/issue", to: "external_relations#update_issue"
    delete "/issue", to: "external_relations#delete_issue"
    get "/issue_done_ratios", to: "external_relations#get_issue_done_ratios"
    patch "/issue_done_ratios", to: "external_relations#update_issue_done_ratios"
    get "/app_title", to: "external_relations#get_app_title"
  end
end
