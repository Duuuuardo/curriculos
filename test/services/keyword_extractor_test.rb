require "test_helper"

class KeywordExtractorTest < ActiveSupport::TestCase
  DESCRIPTION = <<~TEXT.freeze
    Buscamos pessoa desenvolvedora com experiência em ReactJS, TypeScript e Node.
    Desejável conhecimento em AWS e Kubernetes (k8s). Inglês avançado.
    Você vai trabalhar com faturamento recorrente e conciliação bancária.
    O faturamento recorrente é o coração do produto e a conciliação bancária roda todo dia.
  TEXT

  def labels(extractor)
    extractor.keywords.map(&:label)
  end

  test "finds dictionary terms through their variants" do
    found = labels(KeywordExtractor.new(DESCRIPTION))
    assert_includes found, "React"
    assert_includes found, "TypeScript"
    assert_includes found, "Node.js"
    assert_includes found, "Kubernetes"
    assert_includes found, "Inglês"
    assert_not_includes found, "Java"
  end

  test "repeated terms weigh more" do
    keywords = KeywordExtractor.new(DESCRIPTION).keywords.index_by(&:label)
    assert_operator keywords["Kubernetes"].weight, :>, keywords["AWS"].weight
  end

  test "finds frequent domain terms that are not in the dictionary" do
    found = labels(KeywordExtractor.new(DESCRIPTION))
    assert_includes found, "faturamento recorrente"
    assert_includes found, "conciliacao bancaria"
    assert_not_includes found, "pessoa"
  end

  test "finds profile skills mentioned in the job" do
    keyword = KeywordExtractor.new("Experiência com Hotwire e Stimulus", profile_terms: [ "Hotwire" ]).keywords.first
    assert_equal "Hotwire", keyword.label
    assert_equal "profile", keyword.source
  end

  test "supports manual and ignored keywords" do
    extractor = KeywordExtractor.new(DESCRIPTION, extra: [ "liderança", "k8s" ], ignored: [ "aws", "Inglês" ])
    found = labels(extractor)
    assert_includes found, "Liderança"
    assert_equal 1, found.count("Kubernetes")
    assert_not_includes found, "AWS"
    assert_not_includes found, "Inglês"
    assert_equal "manual", extractor.keywords.find { |k| k.label == "Liderança" }.source
  end
end
