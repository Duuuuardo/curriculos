require "test_helper"

class LanguageDetectorTest < ActiveSupport::TestCase
  test "detects portuguese and english job descriptions" do
    assert_equal "pt", LanguageDetector.detect("Buscamos uma pessoa desenvolvedora para atuar com Ruby on Rails no nosso time")
    assert_equal "en", LanguageDetector.detect("We are looking for a developer who will build APIs with our team")
  end

  test "returns nil when there is nothing to go on" do
    assert_nil LanguageDetector.detect("Ruby, Rails, PostgreSQL")
    assert_nil LanguageDetector.detect("")
  end
end
