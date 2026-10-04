# Destaca palavras-chave no texto do currículo com <mark>, ignorando acentos e caixa
# (port do highlight.tsx do frontend).
module HighlightHelper
  def highlight_terms(text, terms)
    return h(text.to_s) if terms.blank? || text.blank?

    chars = text.to_s.chars
    folded_chars = []
    index_map = []
    chars.each_with_index do |char, index|
      fold_char(char).each_char do |folded|
        folded_chars << folded
        index_map << index
      end
    end

    pattern = terms
      .map { |term| fold_char(term.to_s).strip }
      .reject(&:empty?)
      .sort_by { |term| -term.length }
      .map { |term| Regexp.escape(term) }
      .join("|")
    return h(text.to_s) if pattern.empty?

    regex = /(?<![\p{L}\p{N}])(?:#{pattern})(?![\p{L}\p{N}+#])/
    haystack = folded_chars.join
    output = +""
    cursor = 0

    haystack.to_enum(:scan, regex).each do
      match = Regexp.last_match
      start = index_map[match.begin(0)]
      finish = index_map[match.end(0) - 1] + 1
      next if start < cursor

      output << h(chars[cursor...start].join) if start > cursor
      output << "<mark>#{h(chars[start...finish].join)}</mark>"
      cursor = finish
    end
    output << h(chars[cursor..].join) if cursor < chars.length
    output.html_safe
  end

  private

  def fold_char(char)
    char.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
  end
end
