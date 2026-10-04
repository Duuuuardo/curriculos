# Compara as palavras-chave de uma vaga com o conteúdo do perfil.
class JobAnalysis
  attr_reader :job, :profile

  def initialize(job, profile = Profile.for(job.language))
    @job = job
    @profile = profile
  end

  def keywords
    @keywords ||= KeywordExtractor.new(
      job.description,
      profile_terms: profile_terms,
      extra: job.extra_keywords,
      ignored: job.ignored_keywords
    ).keywords
  end

  def matched?(keyword)
    @matched ||= {}
    @matched.fetch(keyword.term) { @matched[keyword.term] = keyword.matches?(corpus) }
  end

  def score
    total = keywords.sum(&:weight)
    return 0 if total.zero?

    (keywords.select { |keyword| matched?(keyword) }.sum(&:weight) * 100 / total).round
  end

  def score_text(text)
    folded = TextNormalizer.fold(text)
    return 0 if folded.empty?

    keywords.sum { |keyword| keyword.matches?(folded) ? keyword.weight : 0 }
  end

  def as_json(*)
    {
      keywords: keywords.map do |keyword|
        keyword.to_h.slice(:term, :label, :variants, :source).merge(weight: keyword.weight, matched: matched?(keyword))
      end,
      matched: keywords.select { |keyword| matched?(keyword) }.map(&:label),
      missing: keywords.reject { |keyword| matched?(keyword) }.map(&:label),
      score: score
    }
  end

  private

  def profile_terms
    profile.skills.map(&:name) +
      profile.experiences.flat_map(&:skills) +
      profile.projects.flat_map(&:skills) +
      profile.certifications.map(&:name)
  end

  def corpus
    @corpus ||= TextNormalizer.fold(
      [
        profile.headline, profile.summary,
        profile.experiences.map { |e| [ e.role, e.company, e.bullets.map { |b| b["text"] }, e.skills ] },
        profile.projects.map { |p| [ p.name, p.description, p.bullets.map { |b| b["text"] }, p.skills ] },
        profile.skills.map { |s| [ s.name, s.category ] },
        profile.educations.map { |e| [ e.degree, e.field, e.institution, e.description ] },
        profile.certifications.map { |c| [ c.name, c.issuer ] },
        profile.languages.map(&:name),
        job.custom_summary, job.custom_headline
      ].flatten.compact.join(" \n ")
    )
  end
end
