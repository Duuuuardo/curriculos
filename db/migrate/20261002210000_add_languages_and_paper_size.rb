class AddLanguagesAndPaperSize < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :language, :string, null: false, default: "pt"
    add_index :profiles, :language, unique: true

    add_column :jobs, :language, :string, null: false, default: "pt"
    change_column_default :jobs, :language, from: "pt", to: nil

    add_column :settings, :paper_size, :string, null: false, default: "letter"
    change_column_default :settings, :accent_color, from: "#1f4e79", to: "#000000"
  end
end
