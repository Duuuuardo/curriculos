# Monta o currículo adaptado para uma vaga: ordena e seleciona tópicos, projetos e competências
# pela relevância, respeitando as escolhas manuais salvas em job.overrides.
class ResumeTailor
  OTHER_SKILLS = { "pt" => "Outras", "en" => "Other" }.freeze
  MAX_CERTIFICATIONS = 4
  MIN_PROJECTS = 2

  def initialize(job, profile = Profile.for(job.language), settings = Setting.current)
    @job = job
    @profile = profile
    @settings = settings
    @analysis = JobAnalysis.new(job, profile)
  end

  attr_reader :analysis

  def as_json(*)
    { analysis: analysis.as_json, resume: resume }
  end

  def resume
    merge_ai_content(deep_clean(
      language: @job.language,
      accent_color: @settings.accent_color,
      paper_size: @settings.paper_size,
      header: header,
      summary: @job.custom_summary.presence || @profile.summary,
      experiences: experiences,
      projects: projects,
      educations: @profile.educations.map { |e| entry("edu:#{e.id}", e, Profile::SECTIONS[:educations], auto: true) },
      certifications: certifications,
      languages: @profile.languages.map { |l| l.slice(:id, :name, :level) },
      skill_groups: skill_groups
    ))
  end

  # Mapa de tudo que pode ser ligado/desligado nesta vaga:
  # chave → { included: bool, label: "rótulo legível" }
  # Usado pelo formulário de ajustes, pelo AiAdapter e pelo Assistente.
  def toggleable_keys
    data = resume
    map = {}
    (data[:experiences] + data[:projects] + data[:educations] + data[:certifications]).each do |entry|
      map[entry[:key]] = { included: entry[:included], label: tailorable_label(entry[:item]) }
      entry[:bullets].each do |bullet|
        map[bullet[:key]] = { included: bullet[:included],
                              label: "#{tailorable_label(entry[:item])} → #{bullet[:text].truncate(60)}" }
      end
    end
    data[:skill_groups].each do |group|
      group[:skills].each do |skill|
        map[skill[:key]] = { included: skill[:included], label: "competência: #{skill[:name]}" }
      end
    end
    map
  end

  private

  # Aplica o conteúdo criado pela IA para esta vaga (job.ai_content):
  # {"rewrites": {bullet_key => texto}, "bullets": [{parent_key, text}],
  #  "entries": [{section, item, bullets}], "skills": [nomes]}
  AI_CONTENT_SECTIONS = %w[experiences projects educations certifications].freeze

  def merge_ai_content(data)
    content = @job.ai_content
    return data unless content.is_a?(Hash) && content.values.any? { |v| v.present? }

    rewrites = content["rewrites"].is_a?(Hash) ? content["rewrites"] : {}
    added = Array(content["bullets"]).select { |b| b.is_a?(Hash) }.group_by { |b| b["parent_key"] }

    %i[experiences projects educations certifications].each do |section|
      data[section].each do |entry|
        entry[:bullets].each do |bullet|
          bullet[:text] = rewrites[bullet[:key]] if rewrites.key?(bullet[:key])
        end
        Array(added[entry[:key]]).each_with_index do |bullet, index|
          entry[:bullets] << { key: "#{entry[:key]}:ai:#{index}", text: bullet["text"].to_s, score: nil, included: true }
        end
      end
    end

    Array(content["entries"]).each_with_index do |spec, index|
      next unless spec.is_a?(Hash)

      section = spec["section"].to_s
      next unless AI_CONTENT_SECTIONS.include?(section)

      item = (spec["item"] || {}).symbolize_keys
      next if item.empty?

      item[:skills] = Array(item[:skills]).map(&:to_s)
      key = "ai:#{section}:#{index}"
      data[section.to_sym] << {
        key: key, included: true, score: nil, item: item,
        bullets: Array(spec["bullets"]).each_with_index.map do |text, i|
          { key: "#{key}:b:#{i}", text: text.to_s, score: nil, included: true }
        end
      }
    end

    names = Array(content["skills"]).map(&:to_s).reject(&:blank?)
    if names.any?
      others = OTHER_SKILLS.fetch(@job.language)
      new_skills = names.map do |name|
        { key: "ai:skill:#{TextNormalizer.fold(name)}", name: name, level: "", matched: false, included: true }
      end
      group = data[:skill_groups].find { |g| g[:category] == others }
      group ? group[:skills].concat(new_skills) : data[:skill_groups] << { category: others, skills: new_skills }
    end

    data
  end

  def tailorable_label(item)
    [ item[:role], item[:company], item[:name], item[:degree], item[:institution] ]
      .compact_blank.join(" · ").presence || "(item)"
  end

  # O currículo não usa travessão: normaliza en/em dashes vindos do perfil para hífen.
  def deep_clean(node)
    case node
    when String then node.tr("–—", "-")
    when Array then node.map { |value| deep_clean(value) }
    when Hash then node.transform_values { |value| deep_clean(value) }
    else node
    end
  end

  def header
    @profile.slice(:full_name, :email, :phone, :location, :linkedin, :github, :website)
            .merge(headline: @job.custom_headline.presence || @profile.headline)
  end

  def experiences
    @profile.experiences.map do |experience|
      entry("exp:#{experience.id}", experience, Profile::SECTIONS[:experiences], auto: true, bullets: true)
    end
  end

  def projects
    scored = @profile.projects.map { |project| [ project, score_record(project) ] }
    any_relevant = scored.any? { |_, score| score.positive? }
    ranked = stable_sort_desc(scored)
    ranked.each_with_index.map do |(project, score), index|
      auto = any_relevant ? score.positive? : index < MIN_PROJECTS
      entry("proj:#{project.id}", project, Profile::SECTIONS[:projects], auto: auto, bullets: true, score: score)
    end
  end

  def certifications
    scored = @profile.certifications.map { |c| [ c, analysis.score_text("#{c.name} #{c.issuer}") ] }
    stable_sort_desc(scored).each_with_index.map do |(certification, score), index|
      entry("cert:#{certification.id}", certification, Profile::SECTIONS[:certifications],
            auto: index < MAX_CERTIFICATIONS, score: score)
    end
  end

  def skill_groups
    skills = @profile.skills.map do |skill|
      { key: "skill:#{skill.id}", name: skill.name, level: skill.level, category: skill.category,
        matched: analysis.score_text(skill.name).positive? }
    end
    known = skills.map { |s| TextNormalizer.fold(s[:name]) }.to_set
    tag_skills = (@profile.experiences.flat_map(&:skills) + @profile.projects.flat_map(&:skills))
                 .uniq { |name| TextNormalizer.fold(name) }
                 .reject { |name| known.include?(TextNormalizer.fold(name)) }
                 .select { |name| analysis.score_text(name).positive? }
                 .map do |name|
                   { key: "tag:#{TextNormalizer.fold(name)}", name: name, level: "", category: OTHER_SKILLS.fetch(@job.language),
                     matched: true }
                 end
    all = skills + tag_skills

    budget = @settings.max_skills
    ordered = all.select { |s| s[:matched] } + all.reject { |s| s[:matched] }
    ordered.each_with_index do |skill, index|
      skill[:included] = @job.overrides.fetch(skill[:key], skill[:matched] || index < budget)
    end

    categories = all.map { |s| s[:category].to_s.strip }.uniq
    ordered.group_by { |s| s[:category].to_s.strip }
           .sort_by { |category, _| categories.index(category) }
           .map { |category, items| { category: category, skills: items.map { |s| s.except(:category) } } }
  end

  def entry(key, record, attributes, auto:, bullets: false, score: nil)
    {
      key: key,
      included: @job.overrides.fetch(key, auto),
      score: score || score_record(record),
      item: record.slice(:id, *attributes),
      bullets: bullets ? tailored_bullets(key, record.bullets) : []
    }
  end

  def tailored_bullets(parent_key, bullets)
    scored = bullets.map { |bullet| [ bullet, analysis.score_text(bullet["text"]) ] }
    stable_sort_desc(scored).each_with_index.map do |(bullet, score), index|
      key = "#{parent_key}:b:#{bullet['id']}"
      { key: key, text: bullet["text"], score: score, included: @job.overrides.fetch(key, index < @settings.max_bullets) }
    end
  end

  def score_record(record)
    texts = record.attributes.values_at("role", "name", "description").compact
    texts += record.bullets.map { |b| b["text"] } + record.skills if record.respond_to?(:bullets)
    analysis.score_text(texts.join(" \n "))
  end

  def stable_sort_desc(pairs)
    pairs.each_with_index.sort_by { |(_, score), index| [ -score, index ] }.map(&:first)
  end
end
