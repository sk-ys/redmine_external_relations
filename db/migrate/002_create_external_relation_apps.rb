class CreateExternalRelationApps < ActiveRecord::Migration[5.2]
  def self.up
    create_table :external_relation_apps do |t|
      t.string :app_name
      t.string :app_title
    end

    # create default
    ExternalRelationApp.create app_name: "local", app_title: "local"
  end
  def self.down
    drop_table :external_relation_apps
  end
end
