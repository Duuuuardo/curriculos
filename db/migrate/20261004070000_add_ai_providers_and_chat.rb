class AddAiProvidersAndChat < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :ai_provider, :string, default: "ollama", null: false
    add_column :settings, :ai_api_key, :string, default: "", null: false
    add_column :settings, :ai_base_url, :string, default: "", null: false
    add_column :settings, :ai_model, :string, default: "", null: false

    create_table :chat_messages do |t|
      t.string :role, null: false
      t.text :content, default: "", null: false
      t.timestamps
    end
  end
end
