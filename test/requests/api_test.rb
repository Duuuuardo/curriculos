require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  def json
    JSON.parse(response.body)
  end

  test "profile can be saved with nested sections, reordered and pruned" do
    put "/api/profile", params: {
      profile: {
        full_name: "Maria",
        experiences: [
          { company: "A", role: "Dev", bullets: [ { text: "Fiz APIs" }, { text: "  " } ], skills: [ "Ruby", "" ] },
          { company: "B", role: "Estagiária" }
        ],
        skills: [ { name: "Ruby", category: "Linguagens" } ]
      }
    }, as: :json
    assert_response :success
    assert_equal "Maria", json["full_name"]
    assert_equal [ "A", "B" ], json["experiences"].map { |e| e["company"] }
    bullets = json["experiences"].first["bullets"]
    assert_equal 1, bullets.size
    assert bullets.first["id"].present?
    assert_equal [ "Ruby" ], json["experiences"].first["skills"]

    first, second = json["experiences"]
    put "/api/profile", params: { profile: { experiences: [ second, first.merge("role" => "Dev Sênior") ] } }, as: :json
    assert_response :success
    assert_equal [ "B", "A" ], json["experiences"].map { |e| e["company"] }
    assert_equal [ second["id"], first["id"] ], json["experiences"].map { |e| e["id"] }
    assert_equal 1, json["skills"].size

    put "/api/profile", params: { profile: { experiences: [ first ] } }, as: :json
    assert_equal 1, Experience.count
  end

  test "jobs crud, duplicate and tailored resume" do
    post "/api/jobs", params: { job: { title: "Dev Rails", description: "Ruby on Rails e PostgreSQL" } }, as: :json
    assert_response :created
    id = json["id"]
    assert_equal "salva", json["status"]

    patch "/api/jobs/#{id}", params: { job: { status: "aplicada", overrides: { "proj:1" => true }, extra_keywords: [ "Docker" ] } },
                             as: :json
    assert_response :success
    assert_equal({ "proj:1" => true }, json["overrides"])

    get "/api/jobs/#{id}/tailored"
    assert_response :success
    assert_includes json["analysis"]["keywords"].map { |k| k["label"] }, "Docker"
    assert json["resume"].key?("skill_groups")

    post "/api/jobs/#{id}/duplicate"
    assert_response :created
    assert_equal "Dev Rails (cópia)", json["title"]

    get "/api/jobs"
    assert_equal 2, json.size
    assert json.first.key?("match_score")

    delete "/api/jobs/#{id}"
    assert_response :no_content
    get "/api/jobs/#{id}"
    assert_response :not_found
  end

  test "job validation errors" do
    post "/api/jobs", params: { job: { title: "" } }, as: :json
    assert_response :unprocessable_content
    assert json["errors"].any?
  end

  test "settings" do
    put "/api/settings", params: { settings: { language: "en", max_bullets: 3 } }, as: :json
    assert_response :success
    assert_equal "en", json["language"]

    put "/api/settings", params: { settings: { language: "xx" } }, as: :json
    assert_response :unprocessable_content
  end

  test "backup round trip keeps ids" do
    post "/api/backup/sample"
    assert_response :no_content
    get "/api/backup"
    backup = json
    assert_equal [ "Ana Souza" ], backup["profiles"].map { |p| p["full_name"] }

    Profile.for("pt").update!(full_name: "Outra")
    post "/api/backup", params: { backup: backup }, as: :json
    assert_response :no_content
    assert_equal "Ana Souza", Profile.for("pt").full_name
    assert_equal backup["profiles"].first["experiences"].map { |e| e["id"] }, Profile.for("pt").experiences.map(&:id)
    assert_equal 1, Job.count
  end

  test "ai status reports when ollama is unavailable" do
    Setting.current.update!(ollama_url: "http://127.0.0.1:9")
    get "/api/ai/status"
    assert_response :success
    assert_equal false, json["available"]
    assert_match "Ollama", json["error"]

    job = Job.create!(title: "Dev")
    post "/api/jobs/#{job.id}/ai/summary"
    assert_response :service_unavailable
  end

  test "profiles are kept per language and can be copied" do
    put "/api/profile", params: { profile: { full_name: "Maria", headline: "Desenvolvedora",
                                             experiences: [ { company: "A", role: "Dev", bullets: [ { text: "Fiz APIs" } ] } ] } },
                        as: :json
    get "/api/profile", params: { language: "en" }
    assert_equal "en", json["language"]
    assert_equal "", json["full_name"]

    post "/api/profile/copy", params: { language: "en", from: "pt" }, as: :json
    assert_response :success
    assert_equal "Maria", json["full_name"]
    assert_equal "Fiz APIs", json["experiences"].first["bullets"].first["text"]

    put "/api/profile?language=en", params: { profile: { headline: "Developer" } }, as: :json
    assert_equal "Developer", Profile.for("en").headline
    assert_equal "Desenvolvedora", Profile.for("pt").headline
    assert_equal 2, Experience.count

    post "/api/profile/copy", params: { language: "pt", from: "pt" }, as: :json
    assert_response :bad_request
  end

  test "job language is detected, used for the resume and can be switched on duplicate" do
    Profile.for("en").update!(full_name: "Mary", headline: "Backend Developer")
    post "/api/jobs", params: { job: { title: "Rails Dev", description: "We are looking for a developer with Ruby on Rails and you will work with our team" } },
                      as: :json
    assert_equal "en", json["language"]
    id = json["id"]
    get "/api/jobs/#{id}/tailored"
    assert_equal "en", json["resume"]["language"]
    assert_equal "Backend Developer", json["resume"]["header"]["headline"]
    assert_equal "letter", json["resume"]["paper_size"]

    patch "/api/jobs/#{id}", params: { job: { overrides: { "exp:1" => false } } }, as: :json
    post "/api/jobs/#{id}/duplicate", params: { language: "pt" }, as: :json
    assert_equal "pt", json["language"]
    assert_equal "Rails Dev (PT)", json["title"]
    assert_equal({}, json["overrides"])

    post "/api/jobs", params: { job: { title: "Dev", language: "pt", description: "We need Ruby" } }, as: :json
    assert_equal "pt", json["language"]
  end

  test "imports version 1 backups with a single profile" do
    sample = Backup.sample
    legacy = sample.except("profiles").merge("version" => 1, "profile" => sample.fetch("profile") { sample["profiles"].first })
    post "/api/backup", params: { backup: legacy }, as: :json
    assert_response :no_content
    assert_equal [ "pt" ], Profile.pluck(:language)
  end
end
