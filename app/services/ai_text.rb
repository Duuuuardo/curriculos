# Normaliza texto vindo de LLM para não parecer "texto de IA" no currículo:
# remove travessões, aspas tipográficas, bullets unicode, emojis e markdown.
# clean(text)             → texto puro (para resumo, carta, campos do currículo)
# clean(text, markdown: true) → só caracteres (mantém **negrito** e links para o chat/relatório)
class AiText
  EMOJI = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{20E3}\u{23E9}-\u{23FA}\u{25AA}-\u{25FE}]/u.freeze
  SMART_QUOTES = { "“" => '"', "”" => '"', "„" => '"', "«" => '"', "»" => '"',
                   "‘" => "'", "’" => "'", "‚" => "'", "‛" => "'" }.freeze
  SMART_QUOTES_REGEX = /[“”„«»‘’‚‛]/u.freeze

  def self.clean(text, markdown: false)
    out = text.to_s.dup
    out = out.tr("–—‑‒―", "-")
             .gsub(EMOJI, "")
             .gsub(SMART_QUOTES_REGEX) { |char| SMART_QUOTES[char] || char }
    out = strip_markdown(out) unless markdown
    out.gsub(/[ \t]+\n/, "\n").gsub(/\n{3,}/, "\n\n").strip
  end

  # Remove marcação markdown que o modelo insiste em devolver
  def self.strip_markdown(text)
    text.gsub(/\*\*(.+?)\*\*/m, '\1')
        .gsub(/__(.+?)__/m, '\1')
        .gsub(/\*(.+?)\*/m, '\1')
        .gsub(/_(.+?)_/m, '\1')
        .gsub(/`(.+?)`/m, '\1')
        .gsub(/\[(.+?)\]\([^)]*\)/m, '\1')
        .gsub(/^\s*\#{0,6}[#>]+\s*/m, "")
        .gsub(/^\s*[*•‣·]\s+/, "- ")
  end
end
