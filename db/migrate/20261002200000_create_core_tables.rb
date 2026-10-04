class CreateCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      %i[full_name headline email phone location linkedin github website].each do |column|
        t.string column, null: false, default: ""
      end
      t.text :summary, null: false, default: ""
      t.timestamps
    end

    create_table :experiences do |t|
      t.references :profile, null: false, foreign_key: true
      %i[company role location start_date end_date].each { |column| t.string column, null: false, default: "" }
      t.boolean :current, null: false, default: false
      t.json :bullets, null: false, default: []
      t.json :skills, null: false, default: []
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :educations do |t|
      t.references :profile, null: false, foreign_key: true
      %i[institution degree field start_date end_date].each { |column| t.string column, null: false, default: "" }
      t.text :description, null: false, default: ""
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :skills do |t|
      t.references :profile, null: false, foreign_key: true
      %i[name category level].each { |column| t.string column, null: false, default: "" }
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :projects do |t|
      t.references :profile, null: false, foreign_key: true
      %i[name url].each { |column| t.string column, null: false, default: "" }
      t.text :description, null: false, default: ""
      t.json :bullets, null: false, default: []
      t.json :skills, null: false, default: []
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :languages do |t|
      t.references :profile, null: false, foreign_key: true
      %i[name level].each { |column| t.string column, null: false, default: "" }
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :certifications do |t|
      t.references :profile, null: false, foreign_key: true
      %i[name issuer date url].each { |column| t.string column, null: false, default: "" }
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :jobs do |t|
      %i[title company url custom_headline].each { |column| t.string column, null: false, default: "" }
      t.string :status, null: false, default: "salva"
      %i[description notes custom_summary cover_letter].each { |column| t.text column, null: false, default: "" }
      t.json :extra_keywords, null: false, default: []
      t.json :ignored_keywords, null: false, default: []
      t.json :overrides, null: false, default: {}
      t.timestamps
    end

    create_table :settings do |t|
      t.string :language, null: false, default: "pt"
      t.string :accent_color, null: false, default: "#1f4e79"
      t.integer :max_bullets, null: false, default: 4
      t.integer :max_skills, null: false, default: 18
      t.string :ollama_url, null: false, default: "http://localhost:11434"
      t.string :ollama_model, null: false, default: ""
      t.timestamps
    end
  end
end
