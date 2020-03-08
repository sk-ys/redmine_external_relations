class CreateExternalRelations < ActiveRecord::Migration[5.2]
  def change
    create_table :external_relations do |t|
      t.integer :issue_from_id
      t.integer :issue_to_id
    end
  end
end
