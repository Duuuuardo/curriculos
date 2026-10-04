# Extrai palavras-chave de uma descrição de vaga, sem IA:
# termos de um dicionário, competências do próprio perfil citadas na vaga e termos que se repetem no texto.
class KeywordExtractor
  WEIGHTS = { "manual" => 3.0, "dictionary" => 2.0, "profile" => 2.0, "frequent" => 1.0 }.freeze

  Keyword = Struct.new(:term, :label, :variants, :count, :source, keyword_init: true) do
    def weight
      bonus = source == "manual" ? 0 : [ count - 1, 3 ].min * 0.5
      WEIGHTS.fetch(source) + bonus
    end

    def matches?(folded_text)
      variants.any? { |variant| TextNormalizer.include?(folded_text, variant) }
    end
  end

  MAX_FREQUENT = 12
  TOKEN = /[\p{L}\p{N}][\p{L}\p{N}+#.\-]*[\p{L}\p{N}+#]|[\p{L}\p{N}]/

  def initialize(description, profile_terms: [], extra: [], ignored: [])
    @text = TextNormalizer.fold(description)
    @profile_terms = profile_terms
    @extra = extra
    @ignored = ignored.map { |term| TextNormalizer.fold(term) }.to_set
  end

  def keywords
    @keywords ||= begin
      found = manual_keywords + dictionary_keywords
      found += profile_keywords(found)
      found += frequent_keywords(found)
      found
        .reject { |keyword| ignored?(keyword) }
        .uniq(&:term)
        .sort_by { |keyword| [ -keyword.weight, keyword.label ] }
    end
  end

  private

  attr_reader :text

  def ignored?(keyword)
    @ignored.include?(keyword.term) || keyword.variants.any? { |variant| @ignored.include?(TextNormalizer.fold(variant)) }
  end

  def manual_keywords
    @extra.map do |label|
      term = TextNormalizer.fold(label)
      entry = dictionary_entry_for(term)
      variants = entry ? entry.last : [ term ]
      Keyword.new(term: entry ? TextNormalizer.fold(entry.first) : term, label: entry ? entry.first : label,
                  variants: variants, count: 1, source: "manual")
    end
  end

  def dictionary_keywords
    KeywordDictionary::ENTRIES.filter_map do |label, variants|
      count = variants.sum { |variant| TextNormalizer.count(text, variant) }
      next if count.zero?

      Keyword.new(term: TextNormalizer.fold(label), label: label, variants: variants, count: count, source: "dictionary")
    end
  end

  def profile_keywords(found)
    @profile_terms.uniq { |term| TextNormalizer.fold(term) }.filter_map do |label|
      term = TextNormalizer.fold(label)
      next if term.length < 2 || covered?(found, term)

      count = TextNormalizer.count(text, term)
      next if count.zero?

      Keyword.new(term: term, label: label, variants: [ term ], count: count, source: "profile")
    end
  end

  def frequent_keywords(found)
    counts = Hash.new(0)
    tokens = text.scan(TOKEN)
    tokens.each_with_index do |token, index|
      next unless candidate?(token)

      counts[token] += 1
      following = tokens[index + 1]
      counts["#{token} #{following}"] += 1 if following && candidate?(following)
    end

    counts
      .select { |term, count| count >= 2 && !covered?(found, term) }
      .sort_by { |term, count| [ -count, -term.length, term ] }
      .first(MAX_FREQUENT)
      .map { |term, count| Keyword.new(term: term, label: term, variants: [ term ], count: count, source: "frequent") }
  end

  def candidate?(token)
    token.length >= 3 && !token.match?(/\A[\d.\-]+\z/) && !Stopwords.include?(token)
  end

  def covered?(found, term)
    found.any? do |keyword|
      keyword.term == term || keyword.variants.any? do |variant|
        variant = TextNormalizer.fold(variant)
        variant == term || TextNormalizer.include?(term, variant) || TextNormalizer.include?(variant, term)
      end
    end
  end

  def dictionary_entry_for(term)
    KeywordDictionary::ENTRIES.find do |label, variants|
      TextNormalizer.fold(label) == term || variants.any? { |variant| TextNormalizer.fold(variant) == term }
    end
  end
end
