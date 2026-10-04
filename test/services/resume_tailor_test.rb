require "test_helper"

class ResumeTailorTest < ActiveSupport::TestCase
  setup do
    Backup.import(Backup.sample)
    @job = Job.first
  end

  def tailored(job = @job)
    ResumeTailor.new(job).as_json
  end

  test "scores the profile against the job" do
    analysis = tailored[:analysis]
    assert_includes analysis[:matched], "Ruby on Rails"
    assert_includes analysis[:missing], "Kubernetes"
    assert_includes analysis[:matched], "Code review"
    assert analysis[:score].between?(1, 99)
  end

  test "orders bullets by relevance and keeps the most relevant within the limit" do
    bullets = tailored[:resume][:experiences].first[:bullets]
    assert_match "Ruby on Rails", bullets.first[:text]
    assert_equal Setting.current.max_bullets, bullets.count { |b| b[:included] }
    assert_not bullets.find { |b| b[:text].include?("Scrum") }[:included]
  end

  test "includes only relevant projects" do
    projects = tailored[:resume][:projects].to_h { |p| [ p[:item]["name"], p[:included] ] }
    assert projects["FinançasFácil"]
    assert_not projects["Portfólio de design"]
  end

  test "puts matched skills first and fills up to max_skills" do
    Setting.current.update!(max_skills: 10)
    groups = tailored[:resume][:skill_groups]
    skills = groups.flat_map { |g| g[:skills] }
    assert_equal 10, skills.count { |s| s[:included] }
    assert skills.select { |s| s[:matched] }.all? { |s| s[:included] }
    assert groups.first[:skills].first[:matched]
    assert_includes skills.map { |s| s[:name] }, "Sidekiq"

    Setting.current.update!(max_skills: 1)
    skills = tailored[:resume][:skill_groups].flat_map { |g| g[:skills] }
    assert_equal skills.count { |s| s[:matched] }, skills.count { |s| s[:included] }
  end

  test "manual overrides win over automatic choices" do
    resume = tailored[:resume]
    design = resume[:projects].find { |p| p[:item]["name"] == "Portfólio de design" }
    top_bullet = resume[:experiences].first[:bullets].first
    @job.update!(overrides: { design[:key] => true, top_bullet[:key] => false })

    resume = tailored[:resume]
    assert resume[:projects].find { |p| p[:key] == design[:key] }[:included]
    assert_not resume[:experiences].first[:bullets].find { |b| b[:key] == top_bullet[:key] }[:included]
  end

  test "uses custom headline and summary for the job" do
    @job.update!(custom_summary: "Resumo da vaga")
    resume = tailored[:resume]
    assert_equal "Resumo da vaga", resume[:summary]
    assert_equal "Desenvolvedora Back-end Ruby on Rails", resume[:header]["headline"]
  end
end
