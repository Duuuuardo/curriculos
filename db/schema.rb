# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_04_100000) do
  create_table "ai_edits", force: :cascade do |t|
    t.integer "job_id", null: false
    t.string "kind", null: false
    t.text "description", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_ai_edits_on_job_id"
  end

  create_table "certifications", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "name", default: "", null: false
    t.string "issuer", default: "", null: false
    t.string "date", default: "", null: false
    t.string "url", default: "", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_certifications_on_profile_id"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.string "role", null: false
    t.text "content", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "educations", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "institution", default: "", null: false
    t.string "degree", default: "", null: false
    t.string "field", default: "", null: false
    t.string "start_date", default: "", null: false
    t.string "end_date", default: "", null: false
    t.text "description", default: "", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_educations_on_profile_id"
  end

  create_table "experiences", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "company", default: "", null: false
    t.string "role", default: "", null: false
    t.string "location", default: "", null: false
    t.string "start_date", default: "", null: false
    t.string "end_date", default: "", null: false
    t.boolean "current", default: false, null: false
    t.json "bullets", default: [], null: false
    t.json "skills", default: [], null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_experiences_on_profile_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.string "title", default: "", null: false
    t.string "company", default: "", null: false
    t.string "url", default: "", null: false
    t.string "custom_headline", default: "", null: false
    t.string "status", default: "salva", null: false
    t.text "description", default: "", null: false
    t.text "notes", default: "", null: false
    t.text "custom_summary", default: "", null: false
    t.text "cover_letter", default: "", null: false
    t.json "extra_keywords", default: [], null: false
    t.json "ignored_keywords", default: [], null: false
    t.json "overrides", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "language", null: false
    t.text "ai_analysis"
    t.text "ai_instructions", default: "", null: false
    t.json "ai_content", default: {}, null: false
  end

  create_table "languages", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "name", default: "", null: false
    t.string "level", default: "", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_languages_on_profile_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "full_name", default: "", null: false
    t.string "headline", default: "", null: false
    t.string "email", default: "", null: false
    t.string "phone", default: "", null: false
    t.string "location", default: "", null: false
    t.string "linkedin", default: "", null: false
    t.string "github", default: "", null: false
    t.string "website", default: "", null: false
    t.text "summary", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "language", default: "pt", null: false
    t.index ["language"], name: "index_profiles_on_language", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "name", default: "", null: false
    t.string "url", default: "", null: false
    t.text "description", default: "", null: false
    t.json "bullets", default: [], null: false
    t.json "skills", default: [], null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_projects_on_profile_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "language", default: "pt", null: false
    t.string "accent_color", default: "#000000", null: false
    t.integer "max_bullets", default: 4, null: false
    t.integer "max_skills", default: 18, null: false
    t.string "ollama_url", default: "http://localhost:11434", null: false
    t.string "ollama_model", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "paper_size", default: "letter", null: false
    t.string "ai_provider", default: "ollama", null: false
    t.string "ai_api_key", default: "", null: false
    t.string "ai_base_url", default: "", null: false
    t.string "ai_model", default: "", null: false
  end

  create_table "skills", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.string "name", default: "", null: false
    t.string "category", default: "", null: false
    t.string "level", default: "", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_skills_on_profile_id"
  end

  add_foreign_key "ai_edits", "jobs"
  add_foreign_key "certifications", "profiles"
  add_foreign_key "educations", "profiles"
  add_foreign_key "experiences", "profiles"
  add_foreign_key "languages", "profiles"
  add_foreign_key "projects", "profiles"
  add_foreign_key "skills", "profiles"
end
