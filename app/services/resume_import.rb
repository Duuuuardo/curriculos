require "pdf-reader"
require "json"

# Lê o texto de um PDF de currículo e transforma em atributos de Profile.
# PDFs do LinkedIn ("Salvar em PDF") têm formato conhecido e usam um parser dedicado;
# os demais passam por heurísticas genéricas e, se o Ollama estiver disponível, por
# uma extração com IA que cobre layouts fora do padrão.
class ResumeImport
  Result = Data.define(:data, :source, :ai_used, :text)

  class Error < StandardError; end

  MONTHS = {
    "jan" => 1, "janeiro" => 1, "january" => 1,
    "fev" => 2, "feb" => 2, "fevereiro" => 2, "february" => 2,
    "mar" => 3, "março" => 3, "marco" => 3, "march" => 3,
    "abr" => 4, "abril" => 4, "apr" => 4, "april" => 4,
    "mai" => 5, "maio" => 5, "may" => 5,
    "jun" => 6, "junho" => 6, "june" => 6,
    "jul" => 7, "julho" => 7, "july" => 7,
    "ago" => 8, "agosto" => 8, "aug" => 8, "august" => 8,
    "set" => 9, "setembro" => 9, "sep" => 9, "sept" => 9, "september" => 9,
    "out" => 10, "outubro" => 10, "oct" => 10, "october" => 10,
    "nov" => 11, "novembro" => 11, "november" => 11,
    "dez" => 12, "dezembro" => 12, "dec" => 12, "december" => 12
  }.freeze

  MONTH_TOKEN = MONTHS.keys.join("|")
  DATE = /(#{MONTH_TOKEN})\.?\s*(?:de\s+)?(\d{4})/i
  PRESENT = /present(?:e)?|atual(?:idade)?|o momento|hoje|current|now|previsto|expected|cursando|em andamento|ongoing|in progress/i
  RANGE_SEP = /(?:\s*[-–—aà]\s*(?:de\s+)?| to )/i
  DATE_RANGE = /\(?\s*#{DATE.source}\s*#{RANGE_SEP.source}\s*(?:#{DATE.source}|#{PRESENT.source})/i
  YEAR_RANGE = /\(?\s*((?:19|20)\d{2})\s*[-–—]\s*((?:19|20)\d{2}|#{PRESENT.source})/i

  EMPLOYMENT_TYPE = /tempo integral|integral|full[- ]time|part[- ]time|meio per[íi]odo|freelance|aut[ôo]nomo|
                     contrato|contract|est[áa]gio|internship|tempor[áa]rio|temporary|self[- ]employed|
                     sazonal|seasonal|aprendiz|volunt[áa]rio|volunteer/i

  COMPANY_HINT = /ltda|inc\b|llc|ltd\b|s\.?a\.?\b|gmbh|me\b|eireli|corp|group|grupo|consulting|consultoria|
                  tecnolog|technolog|software|solutions|solu[çc][õo]es|labs|studio|digital|systems|sistemas/i

  HEADERS = {
    summary: [ "resumo", "summary", "profile", "perfil", "objetivo", "objective", "about", "sobre",
               "sobre mim", "professional summary", "resumo profissional" ],
    experience: [ "experiência", "experience", "experiencias", "experiences", "employment",
                  "experiência profissional", "work experience", "professional experience",
                  "histórico profissional", "employment history" ],
    education: [ "formação", "education", "educação", "formação acadêmica", "academic background",
                 "escolaridade", "educação e formação", "formação & idiomas", "formação e idiomas",
                 "education & languages", "education and languages" ],
    skills: [ "competências", "skills", "top skills", "principais competências", "habilidades",
              "habilidades técnicas", "tecnologias", "technical skills", "conhecimentos",
              "competências e habilidades", "core technologies" ],
    languages: [ "idiomas", "languages", "línguas" ],
    certifications: [ "certificações", "certifications", "certificados", "licenças", "cursos",
                      "licenses and certifications", "licenses & certifications", "honors-awards",
                      "prêmios e títulos", "cursos e certificações" ],
    projects: [ "projetos", "projects", "projetos pessoais", "personal projects", "side projects" ],
    contact: [ "contact", "contato" ]
  }.freeze

  EMAIL_RE = /[\w.+-]+@[\w-]+\.[\w.]+/
  PHONE_RE = /\+?\d[\d\s().-]{7,}\d/
  URL_RE = %r{(?:https?://)?(?:www\.)?[\w-]+\.(?:com|dev|io|br|me|net|org|app|co)[/\w.?=&#-]*}i

  class << self
    def call(uploaded)
      text = extract_text(uploaded)
      raise Error, "Não consegui ler texto desse PDF (ele pode ser uma imagem escaneada)." if text.blank?

      new(text).call
    rescue PDF::Reader::MalformedPDFError, ArgumentError
      raise Error, "Arquivo inválido — envie um PDF de currículo."
    end

    def extract_text(uploaded)
      path = uploaded.respond_to?(:tempfile) ? uploaded.tempfile.path : uploaded.to_s
      PDF::Reader.open(path) do |reader|
        pairs = reader.pages.each_with_index.flat_map do |page, index|
          page.runs.filter_map { |run| [ index, run ] if run.text.strip.present? }
        end
        columns = split_columns(pairs)
        if columns.size < 2
          reader.pages.map(&:text).join("\n")
        else
          columns.map { |column| column_text(column) }.join("\n")
        end
      end
    end

    # PDFs com coluna lateral (export do LinkedIn: contato/skills à esquerda)
    # misturam as colunas na mesma linha de texto; separa pelas coordenadas,
    # emitindo primeiro a coluna principal inteira e depois a lateral inteira.
    def column_text(pairs)
      pairs.sort_by { |page_index, run| [ page_index, -run.y, run.x ] }
           .chunk { |page_index, run| [ page_index, run.y.round ] }
           .map { |_, group| group.map { |_, run| run.text }.join }
           .join("\n")
    end

    # Agrupa os text runs pela coordenada X; se houver um recuo claro entre o
    # grupo mais à esquerda e o restante, trata como duas colunas. A coluna com
    # mais conteúdo (a principal) vem primeiro.
    def split_columns(pairs)
      sorted = pairs.map { |_, run| run.x }.uniq.sort
      clusters = sorted.chunk_while { |a, b| b - a < 20 }.map(&:to_a)
      return [ pairs ] if clusters.size < 2

      gaps = clusters.each_cons(2).map { |a, b| b.first - a.max }
      boundary = clusters[gaps.each_index.max_by { |i| gaps[i] } + 1].first
      left, right = pairs.partition { |_, run| run.x < boundary }
      return [ pairs ] if left.size < 3
      return [ pairs ] if left.map { |_, run| run.x + run.width }.max >= boundary - 10

      [ right, left ].sort_by { |col| -col.size }
    end
  end

  def initialize(text)
    @lines = text.gsub(/\r/, "").lines.map { |line| clean(line) }
                 .reject { |line| line.empty? || page_marker?(line) }
  end

  def call
    linkedin? ? parse_linkedin : parse_generic
  end

  private

  def clean(line)
    line.gsub(/[•·▪‣◦]/, "•").gsub(/ /, " ").strip
  end

  def page_marker?(line)
    line.match?(/\A(page|página|pag\.?)\s*\d+/i) || line.match?(%r{\A\d+\s*/\s*\d+\z})
  end

  def linkedin?
    @lines.any? { |line| line.match?(/linkedin\.com/i) } &&
      @lines.first(30).any? { |line| %i[summary experience].include?(section_kind(line)) }
  end

  # ---------- extração de contatos (válida para qualquer PDF) ----------

  def extract_contacts(data, lines)
    lines.each do |line|
      data[:email] ||= line[EMAIL_RE]
      data[:linkedin] ||= line[URL_RE] if line.match?(/linkedin\.com/i)
      data[:github] ||= line[URL_RE] if line.match?(/github\.com/i)
      data[:website] ||= line[URL_RE] if line.match?(%r{https?://}) &&
                                         !line.match?(/linkedin\.com|github\.com/i)
      next if data[:phone] || line.match?(/@|http|www\./i) || line.match?(/^\d{4}/)

      candidate = line[PHONE_RE]
      data[:phone] = candidate if candidate && candidate.scan(/\d/).size.between?(8, 15)
    end
    data
  end

  # ---------- divisão em seções por títulos conhecidos ----------

  def split_sections(lines)
    sections = Hash.new { |hash, key| hash[key] = [] }
    current = :head
    lines.each do |line|
      kind = section_kind(line)
      if kind
        current = kind
      else
        sections[current] << line
      end
    end
    sections
  end

  def section_kind(line)
    folded = TextNormalizer.fold(line).sub(/[:\-–—|]+\z/, "").strip
    HEADERS.each do |kind, names|
      return kind if names.any? { |name| folded == TextNormalizer.fold(name) }
    end
    nil
  end

  def blank_data
    {
      full_name: nil, headline: nil, email: nil, phone: nil, location: nil,
      linkedin: nil, github: nil, website: nil, summary: nil,
      experiences: [], educations: [], skills: [], projects: [],
      languages: [], certifications: []
    }
  end

  # ---------- parser dedicado ao PDF do LinkedIn ----------

  def parse_linkedin
    sections = split_sections(@lines)
    data = blank_data
    head = sections.delete(:head)

    data[:full_name] = head.first
    rest = head.drop(1)
    extract_contacts(data, rest + @lines)

    contacty = ->(line) { line.match?(EMAIL_RE) || line.match?(URL_RE) || line.match?(/\A\+?\d[\d\s().-]{6,}\z/) }
    leftover = rest.reject { |line| contacty.call(line) }
    location_index = leftover.index { |line| line.match?(LOCATION_HINT) }
    data[:location] = leftover.delete_at(location_index) if location_index
    data[:headline] = leftover.join(" ").presence

    # O PDF do LinkedIn quebra a URL do perfil: "www.linkedin.com/in/" numa
    # linha e "usuario (LinkedIn)" na seguinte.
    if data[:linkedin].to_s.match?(%r{/in/?\z})
      slug = @lines.find { |line| line.match?(/\(linkedin\)/i) }
                   .to_s.sub(/\s*\(linkedin\)\s*/i, "").split(/\s+/).first
      data[:linkedin] = "#{data[:linkedin]}#{slug}" if slug.present?
    end

    data[:summary] = sections[:summary].join(" ").presence
    data[:experiences] = parse_entries(sections[:experience], mode: :experience)
    data[:educations] = parse_educations(sections[:education])
    data[:skills] = parse_skills(sections[:skills])
    data[:languages] = parse_languages(sections[:languages] + language_lines(sections[:education]))
    data[:certifications] = parse_certifications(sections[:certifications])
    data[:projects] = parse_entries(sections[:projects], mode: :project)

    Result.new(data: data, source: :linkedin, ai_used: false, text: @lines.join("\n"))
  end

  # ---------- parser genérico (heurística + IA quando disponível) ----------

  def parse_generic
    ai = AiExtractor.new.resume(@lines.join("\n"))
    if ai
      Result.new(data: normalize_ai_data(ai), source: :generic, ai_used: true, text: @lines.join("\n"))
    else
      Result.new(data: heuristic_parse, source: :generic, ai_used: false, text: @lines.join("\n"))
    end
  end

  def heuristic_parse
    sections = split_sections(@lines)
    data = blank_data
    head = sections.delete(:head)

    extract_contacts(data, head + @lines)
    contacty = ->(line) { line.match?(EMAIL_RE) || line.match?(URL_RE) || line.match?(/\A\+?\d[\d\s().-]{6,}\z/) }
    texty = head.reject { |line| contacty.call(line) }
    data[:full_name] = texty.shift
    data[:headline] = texty.shift
    data[:location] ||= texty.shift

    data[:summary] = sections[:summary].join(" ").presence
    data[:experiences] = parse_entries(sections[:experience], mode: :experience)
    data[:educations] = parse_educations(sections[:education])
    data[:skills] = parse_skills(sections[:skills])
    data[:languages] = parse_languages(sections[:languages] + language_lines(sections[:education]))
    data[:certifications] = parse_certifications(sections[:certifications])
    data[:projects] = parse_entries(sections[:projects], mode: :project)
    data
  end

  # ---------- experiências / projetos ----------

  # Cada item termina numa linha de período ("jan 2020 - atual"). As 1-2 linhas logo
  # acima são título+empresa; abaixo vêm local e descrição até o próximo período.
  def parse_entries(lines, mode:)
    entries = []
    anchors = lines.each_index.select { |i| lines[i].match?(DATE_RANGE) || lines[i].match?(YEAR_RANGE) }
    return parse_undated(lines) if anchors.empty? && mode == :project
    return entries if anchors.empty?

    inlines = anchors.map { |i| inline_header(lines[i]) }

    anchors.each_with_index do |anchor, pos|
      if inlines[pos].present?
        header = [ inlines[pos] ]
      else
        header_start = pos.zero? ? 0 : anchors[pos - 1] + 1
        header = lines[header_start...anchor].reject { |l| bullet?(l) }.last(2)
      end

      next_anchor = anchors[pos + 1]
      gap = next_anchor && inlines[pos + 1].blank? ? 2 : 0
      body_end = next_anchor ? [ next_anchor - gap, anchor + 1 ].max : lines.size
      body = lines[(anchor + 1)...body_end] || []

      entry = build_entry(header, lines[anchor], body, mode, entries.last)
      entries << entry if entry
    end
    entries
  end

  # Projetos normalmente não têm período: cada linha "solta" abre um item e as
  # linhas de bullet seguintes viram suas descrições.
  def parse_undated(lines)
    entries = []
    lines.each do |line|
      if bullet?(line)
        entries.last[:bullets] << { "text" => line.sub(/\A[•\-–*▪]\s*/, "").strip } if entries.any?
        next
      end
      name, _, description = line.partition(/\s+[·|•—–-]\s+/)
      entries << { name: name.strip, url: line[URL_RE].to_s,
                   description: description.strip, bullets: [], skills: [] }
    end
    entries.reject { |e| e[:name].blank? && e[:bullets].empty? }
  end

  # Texto antes do período na própria linha-âncora, em currículos que escrevem
  # "Cargo, Empresa    jan 2020 - atual" numa linha só.
  def inline_header(line)
    line.sub(DATE_RANGE, "").sub(YEAR_RANGE, "").gsub(/\([^)]*\)/, "")
        .gsub(/\A[\s·|,;:\-–—]+|[\s·|,;:\-–—]+\z/, "").strip
  end

  def build_entry(header, date_line, body, mode, previous)
    start_date, end_date, current = parse_dates(date_line)

    location = nil
    if body.first&.match?(LOCATION_HINT) && body.first.length <= 60
      location = body.shift
    end

    # Linhas que não começam com marcador são continuação do bullet anterior
    # (PDFs quebram bullets longos em várias linhas).
    bullets = []
    body.each do |line|
      text = line.sub(/\A[•\-–*▪]\s*/, "").strip
      next if text.empty?

      if bullet?(line) || bullets.empty?
        bullets << { "text" => text }
      else
        bullets.last["text"] += " #{text}"
      end
    end

    title, company = split_title_company(header)
    if company.blank? && previous
      company = previous[:company]
      title ||= nil
    end
    title, company = company, title if company.blank? && title.present?

    case mode
    when :experience
      return nil if title.blank? && company.blank? && bullets.empty?

      { company: company.to_s, role: title.to_s, location: location.to_s,
        start_date: start_date, end_date: end_date, current: current,
        bullets: bullets, skills: extract_inline_skills(bullets) }
    else
      name = title.presence || company
      return nil if name.blank? && bullets.empty?

      { name: name.to_s, url: body.join(" ")[URL_RE].to_s, description: "",
        bullets: bullets, skills: [] }
    end
  end

  def split_title_company(header)
    return [ nil, nil ] if header.empty?

    if header.size == 1
      parts = header.first.split(/\s*[,;|·]\s*|\s+[-–—]\s+|\s+(?:at|na|no|em)\s+/i, 2)
      return parts.size == 2 ? parts : [ header.first, nil ]
    end

    first, second = header

    if (combined = header.join(" ")).match?(/ at | na | no | em /i)
      combined =~ /\A(.+?)\s+(?:at|na|no|em)\s+(.+)\z/i
      return [ Regexp.last_match(1), Regexp.last_match(2) ] if Regexp.last_match
    end

    if second.match?(EMPLOYMENT_TYPE)
      return [ first, second.sub(/\s*[·|,-]?\s*#{EMPLOYMENT_TYPE.source}.*/i, "").strip ]
    end
    if first.match?(EMPLOYMENT_TYPE)
      return [ second, first.sub(/\s*[·|,-]?\s*#{EMPLOYMENT_TYPE.source}.*/i, "").strip ]
    end

    return [ second, first ] if second.match?(ROLE_HINT) && !first.match?(ROLE_HINT)
    return [ first, second ] if first.match?(ROLE_HINT) && !second.match?(ROLE_HINT)
    return [ second, first ] if first.match?(COMPANY_HINT) && !second.match?(COMPANY_HINT)
    return [ first, second ] if second.match?(COMPANY_HINT) && !first.match?(COMPANY_HINT)

    [ first, second ] # padrão LinkedIn: cargo na primeira linha, empresa na segunda
  end

  ROLE_HINT = /engineer|developer|desenvolvedor|engenheiro|manager|gerente|analyst|analista|designer|
               consultant|consultor|intern|estagi|lead|l[íi]der|senior|s[êe]nior|junior|architect|arquiteto|
               scientist|specialist|especialista|coordinator|coordenador|director|diretor|founder|fundador|
               freelance|backend|frontend|full[- ]?stack|devops/i

  LOCATION_HINT = /\A[A-ZÀ-Ú][\p{L} .'-]+,\s*[\p{L} .'-]+\z|\bBrasil\b|\bBrazil\b|\bRemote\b|\bRemoto\b/i

  def bullet?(line)
    line.match?(/\A[•\-–*▪]/)
  end

  def extract_inline_skills(bullets)
    joined = bullets.map { |b| b["text"] }.join(" ")
    joined[/(?:competências|skills|tecnologias|technologies|stack)\s*:\s*(.+)/i, 1]
      .to_s.split(/[,;•]/).map(&:strip).reject(&:empty?).first(15)
  end

  def parse_dates(line)
    tokens = line.scan(DATE)
    if tokens.any?
      start_month, start_year = tokens.first
      start_date = format("%04d-%02d", start_year, MONTHS[TextNormalizer.fold(start_month)])
    elsif line =~ YEAR_RANGE
      start_date = "#{Regexp.last_match(1)}-01"
    end

    if line.match?(PRESENT)
      current = true
      end_date = nil
    elsif tokens.size > 1
      end_month, end_year = tokens[1]
      end_date = format("%04d-%02d", end_year, MONTHS[TextNormalizer.fold(end_month)])
    elsif line =~ YEAR_RANGE
      end_date = Regexp.last_match(2).to_s.match?(/\d{4}/) ? "#{Regexp.last_match(2)}-12" : nil
      current = end_date.nil?
    end

    [ start_date, end_date, current == true ]
  end

  # ---------- demais seções ----------

  def parse_educations(lines)
    anchors = lines.each_index.select { |i| lines[i].match?(DATE_RANGE) || lines[i].match?(YEAR_RANGE) }
    return [] if anchors.empty?

    anchors.each_with_index.filter_map do |anchor, pos|
      start_at = pos.zero? ? 0 : anchors[pos - 1] + 1
      header = (lines[start_at...anchor] + [ inline_header(lines[anchor]) ]).reject(&:empty?)
      next if header.empty?

      start_date, end_date, = parse_dates(lines[anchor])
      institution_re = /universidad|university|faculdade|faculty|college|institut|school|escola/i
      dedicated = header.index { |line| line.match?(institution_re) && !line.match?(/,/) }
      if dedicated
        institution = header[dedicated]
        rest = (header - [ institution ]).join(" ")
      else
        parts = header.join(" ").split(/[,;·]/).map(&:strip).reject(&:empty?)
        institution = parts.find { |p| p.match?(institution_re) } || parts.first
        rest = (parts - [ institution ]).join(", ")
      end
      degree, field = split_degree_field(rest)
      next if institution.blank?

      { institution: institution, degree: degree, field: field,
        start_date: start_date, end_date: end_date, description: nil }
    end
  end

  def split_degree_field(text)
    parts = text.split(/[,;·]| - | – | — /).map(&:strip).reject(&:empty?)
    degree = parts.find { |p| p.match?(/bacharel|bachelor|licenc|master|mestrado|mba|doutor|phd|doctor|
                                        tecn[óo]logo|technologist|associate|ensino m[ée]dio|high school|
                                        p[óo]s[- ]?gradua|especializa|certificate|certificado|degree/i) } || parts.first
    field = (parts - [ degree ]).first.to_s
    [ degree.to_s, field ]
  end

  # Linhas "Backend: Node.js, ..." viram skills com a categoria do prefixo.
  def parse_skills(lines)
    entries = []
    lines.each do |line|
      category = nil
      text = line
      if line =~ /\A([^:]{2,30}):\s*(.+)\z/
        category = Regexp.last_match(1).strip
        text = Regexp.last_match(2)
      end
      text.split(/[,;•|·]/).each do |piece|
        name = piece.sub(/\A[•\-–*]\s*/, "").strip
        next if name.empty? || name.length > 60 || name.match?(/\d{4}/)

        entries << { name: name, category: category, level: nil }
      end
    end
    entries.uniq { |e| e[:name] }
  end

  # Seções combinadas ("Formação & Idiomas") misturam idiomas com formação;
  # linhas com "(Nativo)", "(Fluent)" etc. são extraídas como idioma.
  LEVEL_WORDS = /nativ|fluen|profession|profissional|b[áa]sic|intermedi|avan[çc]|biling|elementar/i

  def language_lines(lines)
    Array(lines).select { |l| l.match?(/\(/) && l.match?(LEVEL_WORDS) }
  end

  def parse_languages(lines)
    lines.flat_map { |line| line.split(/[,;•]/) }.filter_map do |piece|
      piece = piece.strip
      next if piece.empty? || piece.length > 60

      if piece =~ /\A(.+?)\s*[(\[:;-]\s*(.+?)\)?\s*\z/
        name, level = Regexp.last_match(1).strip, Regexp.last_match(2).sub(/\)\z/, "").strip
        { name: name, level: level.presence }
      else
        { name: piece, level: nil }
      end
    end
  end

  def parse_certifications(lines)
    entries = []
    current = nil
    lines.each do |line|
      if line.match?(/emitid|issued|expedid|conclu[íi]d/i) && line.match?(/#{MONTH_TOKEN}|\d{4}/i)
        current[:date] = extract_issue_date(line) if current
        next
      end
      if current && line.length < 80 && !bullet?(line) && current[:issuer].nil? && current[:name].present?
        current[:issuer] = line
        next
      end
      entries << current if current
      current = { name: line.sub(/\A[•\-–*]\s*/, ""), issuer: nil, date: nil, url: line[URL_RE] }
    end
    entries << current if current
    entries.select { |e| e[:name].present? }
  end

  def extract_issue_date(line)
    if (match = line.match(/(#{MONTH_TOKEN})\.?\s*(?:de\s+)?(\d{4})/i))
      format("%04d-%02d", match[2], MONTHS[TextNormalizer.fold(match[1])])
    elsif (match = line.match(/((?:19|20)\d{2})/))
      "#{match[1]}-01"
    end
  end

  # ---------- normalização da resposta da IA ----------

  def normalize_ai_data(ai)
    data = blank_data
    %i[full_name headline email phone location linkedin github website summary].each do |field|
      data[field] = ai[field] || ai[field.to_s]
    end

    data[:experiences] = Array(ai[:experiences] || ai["experiences"]).map do |e|
      e = e.to_h.stringify_keys
      { company: e["company"].to_s, role: e["role"].to_s, location: e["location"].to_s,
        start_date: normalize_date(e["start_date"]), end_date: normalize_date(e["end_date"]),
        current: ActiveModel::Type::Boolean.new.cast(e["current"]),
        bullets: Array(e["bullets"]).map { |b| { "text" => b.is_a?(Hash) ? b["text"].to_s : b.to_s } },
        skills: Array(e["skills"]).map(&:to_s) }
    end
    data[:educations] = Array(ai[:educations] || ai["educations"]).map do |e|
      e = e.to_h.stringify_keys
      { institution: e["institution"].to_s, degree: e["degree"].to_s, field: e["field"].to_s,
        start_date: normalize_date(e["start_date"]), end_date: normalize_date(e["end_date"]),
        description: e["description"].to_s }
    end
    data[:skills] = Array(ai[:skills] || ai["skills"]).map do |s|
      s.is_a?(Hash) ? { name: s["name"].to_s, category: s["category"], level: s["level"] }
                    : { name: s.to_s, category: nil, level: nil }
    end
    data[:projects] = Array(ai[:projects] || ai["projects"]).map do |p|
      p = p.to_h.stringify_keys
      { name: p["name"].to_s, url: p["url"].to_s, description: p["description"].to_s,
        bullets: Array(p["bullets"]).map { |b| { "text" => b.is_a?(Hash) ? b["text"].to_s : b.to_s } },
        skills: Array(p["skills"]).map(&:to_s) }
    end
    data[:languages] = Array(ai[:languages] || ai["languages"]).map do |l|
      l.is_a?(Hash) ? { name: l["name"].to_s, level: l["level"] } : { name: l.to_s, level: nil }
    end
    data[:certifications] = Array(ai[:certifications] || ai["certifications"]).map do |c|
      c = c.to_h.stringify_keys
      { name: c["name"].to_s, issuer: c["issuer"].to_s, date: normalize_date(c["date"]), url: c["url"].to_s }
    end
    extract_contacts(data, @lines.first(30)) # regex como rede de segurança
    data
  end

  def normalize_date(value)
    text = value.to_s.strip
    return nil if text.empty?
    return text[0, 7] if text.match?(/\A\d{4}-\d{2}/)
    return "#{text}-01" if text.match?(/\A(19|20)\d{2}\z/)

    if (match = text.match(/(#{MONTH_TOKEN})\w*\.?\s*(?:de\s+)?(\d{4})/i))
      format("%04d-%02d", match[2], MONTHS[TextNormalizer.fold(match[1])] || 1)
    end
  end
end
