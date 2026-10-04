class CreateAiEdits < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_edits do |t|
      t.references :job, null: false, foreign_key: true
      t.string :kind, null: false
      t.text :description, default: "", null: false
      t.timestamps
    end
  end
end
