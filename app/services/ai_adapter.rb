require "json"

# Aplica o parecer da IA (job.ai_analysis) no currículo da vaga:
# reescreve título/resumo e liga/desliga itens via overrides.
# Devolve { changes: [...], note: "..." } ou nil se falhar.
class AiAdapter
  def initialize(job, profile: Profile.for(job.language), settings: Setting.current)
    @job = job
    @profile = profile
    @settings = settings
    @tailor = ResumeTailor.new(job, profile, settings)
  end

  def call
    return nil if @job.ai_analysis.blank?

    parsed = JSON.parse(ask[/\{.*\}/m].to_s)
    return nil unless parsed.is_a?(Hash)

    apply(parsed)
  rescue LlmClient::Error, JSON::ParserError
    nil
  end

  private

  def apply(parsed)
    changes = []

    %w[custom_headline custom_summary].each do |field|
      value = AiText.clean(parsed[field].to_s)
      next if value.blank? || value == @job.public_send(field)

      @job.public_send("#{field}=", value)
      changes << "#{field == 'custom_headline' ? 'título' : 'resumo'} reescrito"
    end

    overrides = @job.overrides
    keys = valid_keys
    toggled = Array(parsed["toggle_keys"]).select { |k| keys.key?(k["key"]) }
    toggled.each do |toggle|
      key = toggle["key"]
      value = !toggle["include"].nil? ? !!toggle["include"] : !@job.overrides.fetch(key, keys[key][:included])
      next if overrides[key] == value || (!overrides.key?(key) && keys[key][:included] == value)

      overrides[key] = value
      changes << "#{value ? 'incluído' : 'removido'}: #{keys[key][:label]}"
    end

    @job.overrides = overrides if toggled.any?

    content = @job.ai_content.to_h
    Array(parsed["new_bullets"]).each do |bullet|
      next unless bullet.is_a?(Hash)

      parent = bullet["parent_key"].to_s
      text = AiText.clean(bullet["text"].to_s)
      next unless keys.key?(parent) && parent.match?(/\A(exp|proj):\d+\z/) && text.present?

      (content["bullets"] ||= []) << { "parent_key" => parent, "text" => text }
      changes << "novo bullet em #{keys[parent][:label]}"
    end
    Array(parsed["extra_skills"]).each do |name|
      name = AiText.clean(name.to_s)
      next if name.blank? || Array(content["skills"]).include?(name)

      (content["skills"] ||= []) << name
      changes << "competência adicionada: #{name}"
    end
    @job.ai_content = content if content.any? { |_, v| v.present? }

    @job.save! if changes.any?

    { changes: changes, note: AiText.clean(parsed["note"].to_s, markdown: true) }
  end

  # chave → {included, label} de tudo que pode ser ligado/desligado nesta vaga
  def valid_keys
    @valid_keys ||= @tailor.toggleable_keys
  end

  def ask
    LlmClient.generate_text(@settings, <<~PROMPT)
      Você está adaptando um currículo para uma vaga com base num parecer de recrutador.
      Devolva APENAS um JSON válido (sem markdown em volta) neste formato:
      {"custom_headline": "novo título profissional ou null",
       "custom_summary": "novo resumo (3-4 frases, texto puro) ou null",
       "toggle_keys": [{"key": "chave exata da lista", "include": true|false}],
       "new_bullets": [{"parent_key": "chave exp:ID ou proj:ID", "text": "bullet novo"}],
       "extra_skills": ["competência que já existe no perfil e combina com a vaga"],
       "note": "resumo curto do que mudou"}

      Regras:
      - só reescreva headline/resumo se o parecer pedir; senão use null;
      - toggle_keys só para itens que o parecer mandar remover ou incluir; NÃO mexa no resto;
      - new_bullets só para reescrever/destacar fatos que já existem no perfil (nunca invente);
      - nunca invente fatos: textos novos só podem usar o que existe no perfil;
      - texto PURO: sem markdown, sem travessão/en dash, sem aspas tipográficas, sem clichês de IA.

      ## Parecer da IA
      #{@job.ai_analysis.truncate(4000)}

      ## Vaga
      #{@job.title} @ #{@job.company}
      #{@job.description.to_s.truncate(3000)}

      ## Itens do currículo desta vaga (chave → incluído? - rótulo)
      #{valid_keys.map { |key, meta| "#{key} → #{meta[:included] ? 'sim' : 'não'} - #{meta[:label]}" }.join("\n")}

      ## Instruções do candidato
      #{@job.ai_instructions.presence || '(nenhuma)'}
    PROMPT
  end
end
