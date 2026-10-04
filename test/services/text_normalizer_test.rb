require "test_helper"

class TextNormalizerTest < ActiveSupport::TestCase
  test "fold removes accents, case and extra spaces" do
    assert_equal "comunicacao e lideranca", TextNormalizer.fold("  Comunicação   e LIDERANÇA ")
  end

  test "matches whole terms only" do
    text = TextNormalizer.fold("Experiência com Java e C# em microsserviços")
    assert TextNormalizer.include?(text, "java")
    assert TextNormalizer.include?(text, "c#")
    assert_not TextNormalizer.include?(text, "c")
    assert_not TextNormalizer.include?(TextNormalizer.fold("JavaScript"), "java")
  end

  test "handles terms with symbols and plurals" do
    text = TextNormalizer.fold("Node.js, C++, CI/CD e code reviews")
    assert TextNormalizer.include?(text, "node.js")
    assert TextNormalizer.include?(text, "c++")
    assert TextNormalizer.include?(text, "ci/cd")
    assert TextNormalizer.include?(text, "code review")
    assert_equal 1, TextNormalizer.count(text, "node.js")
  end
end
