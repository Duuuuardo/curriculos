class AddAiAnalysisToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :ai_analysis, :text
  end
end
