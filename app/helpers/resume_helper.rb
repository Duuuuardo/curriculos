# Formatações do currículo e rótulos da interface (equivalente ao i18n.ts/labels.ts do frontend).
module ResumeHelper
  LANGUAGE_LABELS = { "pt" => "Português", "en" => "Inglês" }.freeze

  STATUS_LABELS = {
    "salva" => "Salva",
    "aplicada" => "Candidatura enviada",
    "entrevista" => "Entrevista",
    "oferta" => "Oferta",
    "rejeitada" => "Não avançou"
  }.freeze

  HEADINGS = {
    "pt" => {
      summary: "Resumo",
      skills: "Habilidades técnicas",
      experience: "Experiência profissional",
      projects: "Projetos pessoais",
      education: "Formação",
      educationAndLanguages: "Formação & Idiomas",
      languages: "Idiomas",
      certifications: "Certificações",
      present: "Atual",
      inProgress: "cursando",
      fieldJoiner: "em",
      stack: "Stack"
    },
    "en" => {
      summary: "Summary",
      skills: "Technical skills",
      experience: "Professional experience",
      projects: "Projects",
      education: "Education",
      educationAndLanguages: "Education & Languages",
      languages: "Languages",
      certifications: "Certifications",
      present: "Present",
      inProgress: "in progress",
      fieldJoiner: "in",
      stack: "Stack"
    }
  }.freeze

  MONTHS = {
    "pt" => %w[Jan Fev Mar Abr Mai Jun Jul Ago Set Out Nov Dez],
    "en" => %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]
  }.freeze

  def resume_heading(lang, key)
    HEADINGS.fetch(lang.to_s).fetch(key)
  end

  def language_label(lang)
    LANGUAGE_LABELS.fetch(lang.to_s, lang.to_s)
  end

  def status_label(status)
    STATUS_LABELS.fetch(status.to_s, status.to_s)
  end

  def format_month(lang, value)
    match = value.to_s.match(/\A(\d{4})-(\d{2})/)
    return value.to_s unless match

    month = MONTHS.fetch(lang.to_s)[match[2].to_i - 1]
    month ? "#{month} #{match[1]}" : match[1]
  end

  def format_period(lang, start, finish, current = false)
    from = format_month(lang, start)
    to = current ? resume_heading(lang, :present) : format_month(lang, finish)
    [ from, to ].reject(&:empty?).join(" - ")
  end

  def format_years(start, finish)
    year = ->(value) { value.to_s[/\A\d{4}/] }
    [ year.call(start), year.call(finish) ].compact_blank.join(" - ")
  end

  def future_month?(value)
    value.to_s.match?(/\A\d{4}-\d{2}/) && value.to_s[0, 7] > Time.current.strftime("%Y-%m")
  end

  def strip_protocol(url)
    url.to_s.sub(%r{\Ahttps?://(www\.)?}, "").sub(%r{/\z}, "")
  end

  # href clicável para um valor do perfil (e-mail, telefone ou URL).
  # Devolve nil quando o valor não é um link válido (ex.: localização).
  def resume_href(value)
    text = value.to_s.strip
    return if text.empty?

    if text.match?(/\A\S+@\S+\.\S+\z/)
      "mailto:#{text}"
    elsif text.match?(%r{\Ahttps?://}i)
      text
    elsif text.match?(/\A\+?[\d().\-\s]{6,}\z/)
      "tel:#{text.gsub(/[^\d+]/, '')}"
    elsif text.match?(%r{\A[\w.-]+\.[a-z]{2,}([/?#]\S*)?\z}i)
      "https://#{text}"
    end
  end

  # Texto clicável quando o valor é um link; texto puro caso contrário.
  def resume_contact(value)
    href = resume_href(value)
    return h(strip_protocol(value)) if href.nil?

    link_to strip_protocol(value), href, target: "_blank", rel: "noopener"
  end

  def score_badge(score)
    tone = score >= 70 ? "good" : score >= 40 ? "mid" : "low"
    tag.span "#{score}%", class: "score score-#{tone}", title: "Compatibilidade do seu perfil com a vaga"
  end

  def pdf_file_name(name, language, target)
    clean = lambda do |text|
      text.to_s.unicode_normalize(:nfd).gsub(/\p{M}/, "").gsub(/[^A-Za-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    end
    [ clean.call(name).presence || "Curriculo", "CV", language.to_s.upcase, clean.call(target) ]
      .compact_blank.join("_")
  end

  # Resumo de uma linha para os itens das listas do perfil (cargo · empresa, nome — nível etc.)
  def profile_item_summary(record)
    text =
      case record
      when Experience then "#{[ record.role, record.company ].compact_blank.join(' · ')}#{period_suffix(record)}"
      when Project then record.name
      when Skill then [ record.name, record.category ].compact_blank.join(" — ")
      when Education then [ record.degree, record.field, record.institution ].compact_blank.join(" · ")
      when Language then [ record.name, record.level ].compact_blank.join(" — ")
      when Certification then [ record.name, record.issuer ].compact_blank.join(" · ")
      else record.to_s
      end
    text.presence || "(sem título)"
  end

  def period_suffix(record)
    period = format_period("pt", record.start_date, record.end_date, record.current)
    period.present? ? " (#{period})" : ""
  end

  # Título de uma linha para os toggles de "Ajustar currículo" (exp/proj/edu/cert)
  def entry_label(item)
    [ item[:role], item[:company], item[:name], item[:degree], item[:field], item[:institution] ]
      .compact_blank.join(" · ").presence || "(sem título)"
  end

  # Renderiza o markdown mínimo que a IA produz (**negrito**, - listas, ### títulos, parágrafos).
  def markdown_lite(text)
    html = []
    in_list = false
    text.to_s.each_line do |line|
      stripped = line.strip
      if (match = stripped.match(/\A([#]{1,6})\s+(.+)/))
        html << "</ul>" if in_list
        in_list = false
        level = [ match[1].size + 1, 6 ].min
        html << "<h#{level}>#{inline_md(match[2])}</h#{level}>"
      elsif stripped.match?(/\A[-*•]\s+/)
        html << "<ul>" unless in_list
        in_list = true
        html << "<li>#{inline_md(stripped.sub(/\A[-*•]\s+/, ''))}</li>"
      else
        html << "</ul>" if in_list
        in_list = false
        html << (stripped.empty? ? "" : "<p>#{inline_md(stripped)}</p>")
      end
    end
    html << "</ul>" if in_list
    html.join.html_safe
  end

  private

  def inline_md(text)
    ERB::Util.html_escape(text)
             .gsub(/\[(.+?)\]\(([^)\s]+)\)/) do
               safe_url = Regexp.last_match(2)
               if safe_url.match?(%r{\A(/|https?://)}i)
                 %(<a href="#{ERB::Util.html_escape(safe_url)}">#{Regexp.last_match(1)}</a>)
               else
                 Regexp.last_match(1)
               end
             end
             .gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
             .gsub(/\*(.+?)\*/, '<em>\1</em>')
             .html_safe
  end
end
