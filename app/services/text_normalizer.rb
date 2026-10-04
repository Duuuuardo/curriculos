module TextNormalizer
  module_function

  def fold(text)
    text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/\s+/, " ").strip
  end

  def term_regex(term)
    /(?<![\p{L}\p{N}])#{Regexp.escape(fold(term))}(?:e?s)?(?![\p{L}\p{N}+#])/
  end

  def count(folded_text, term)
    folded_text.scan(term_regex(term)).size
  end

  def include?(folded_text, term)
    term_regex(term).match?(folded_text)
  end
end
