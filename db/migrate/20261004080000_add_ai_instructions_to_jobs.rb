class AddAiInstructionsToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :ai_instructions, :text, default: "", null: false
  end
end
