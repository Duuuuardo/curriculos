class AddAiContentToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :ai_content, :json, default: {}, null: false
  end
end
