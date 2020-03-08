class AddAppRefToExternalRelations < ActiveRecord::Migration[5.2]
  def change
    add_reference :external_relations, :issue_from_app, nil: false, foreign_key: { on_delete: :cascade, to_table: :external_relation_apps }, default: 1
    add_reference :external_relations, :issue_to_app, nil: false, foreign_key: { on_delete: :cascade, to_table: :external_relation_apps }, default: 1
  end
end