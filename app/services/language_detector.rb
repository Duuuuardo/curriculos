# Adivinha se um texto está em português ou inglês contando palavras funcionais de cada idioma.
module LanguageDetector
  MARKERS = {
    "pt" => (Stopwords::PORTUGUESE - Stopwords::ENGLISH).to_set,
    "en" => (Stopwords::ENGLISH - Stopwords::PORTUGUESE).to_set
  }.freeze

  def self.detect(text)
    words = TextNormalizer.fold(text).scan(/\p{L}+/)
    counts = MARKERS.transform_values { |markers| words.count { |word| markers.include?(word) } }
    return nil if counts.values.all?(&:zero?)

    counts.max_by { |_, count| count }.first
  end
end
