# Assistente conversacional da aba "Assistente".
# O modelo responde SEMPRE um JSON {"reply": "...", "actions": [...]}; as ações
# são executadas de verdade no app (criar vaga, adaptar currículo, editar perfil).
class Assistant
  MODEL_ATTRS = %i[title company url status language notes description custom_headline custom_summary ai_instructions].freeze
  PROFILE_ATTRS = %i[full_name headline email phone location linkedin github website summary].freeze
  # Campos aceitos em cada seção ao criar uma entrada nova via edit_content
  ENTRY_FIELDS = {
    "experiences"    => %w[role company location start_date end_date current description],
    "projects"       => %w[name description url skills],
    "certifications" => %w[name issuer date url],
    "educations"     => %w[degree field institution start_date end_date description]
  }.freeze
  # chaves que aceitam bullets novos (experiências e projetos, incluindo entradas da IA)
  BULLET_PARENT = /\A(exp:\d+|proj:\d+|ai:(experiences|projects):\d+)\z/.freeze

  attr_reader :touched_job_ids

  def initialize(text, settings: Setting.current, job_id: nil)
    @text = text
    @settings = settings
    @current_job = Job.find_by(id: job_id)
    @touched_job_ids = []
  end

  def call
    raw = LlmClient.chat(@settings, messages: messages)
    parsed = extract_json(raw)
    reply = AiText.clean(parsed["reply"].presence || raw.sub(/\{.*\}\s*\z/m, "").presence || "(sem resposta)",
                         markdown: true)
    results = Array(parsed["actions"]).filter_map { |action| run_action(action) }
    results.any? ? "#{reply}\n\n#{results.join("\n")}" : reply
  rescue LlmClient::Error => e
    raise e
  end

  private

  def messages
    [ { role: "system", content: system_prompt },
      *history.map { |m| { role: m.role, content: m.content } },
      { role: "user", content: @text } ]
  end

  def history
    @history ||= ChatMessage.history(30)
  end

  def extract_json(raw)
    parsed = JSON.parse(raw[/\{.*\}/m].to_s)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end

  # ---------- ações que o assistente pode executar ----------

  def run_action(action)
    return unless action.is_a?(Hash)

    case action["type"]
    when "create_job" then create_job(action)
    when "update_job" then update_job(action)
    when "tailor_summary" then tailor_summary(action)
    when "cover_letter" then cover_letter(action)
    when "analyze_job" then analyze_job(action)
    when "adapt_job" then adapt_job(action)
    when "toggle_items" then toggle_items(action)
    when "edit_content" then edit_content(action)
    when "update_profile" then update_profile(action)
    else nil
    end
  rescue ActiveRecord::RecordInvalid => e
    "⚠️ Não consegui salvar: #{e.record.errors.full_messages.to_sentence}"
  end

  def create_job(action)
    fields = action["fields"].is_a?(Hash) ? action["fields"] : {}
    job = Job.new(clean_fields(fields).slice(*MODEL_ATTRS.map(&:to_s)))
    job.language = fields["language"].presence_in(Setting::LANGUAGES) ||
                   LanguageDetector.detect(job.description.to_s) || @settings.language
    job.save!
    touch(job)
    "✅ Vaga criada: [#{job.title}#{job.company.present? ? " · #{job.company}" : ""}](/jobs/#{job.id})"
  end

  def update_job(action)
    job = find_job(action["job_id"])
    return "⚠️ Vaga ##{action["job_id"]} não encontrada." unless job

    fields = clean_fields(action["fields"].is_a?(Hash) ? action["fields"] : {}).slice(*MODEL_ATTRS.map(&:to_s))
    return "ℹ️ Nada mudou — a vaga já está com esses valores." if fields.all? { |k, v| job.public_send(k).to_s == v.to_s }

    job.update!(fields)
    detail = fields.map { |k, v| "#{k} = \"#{v.to_s.truncate(60)}\"" }.join("; ").truncate(300)
    job.ai_edits.create!(kind: "update", description: "Assistente alterou #{detail}")
    touch(job)
    "✅ Vaga atualizada: [#{job.title}](/jobs/#{job.id}) — a página atualiza sozinha."
  end

  def tailor_summary(action)
    job = find_job(action["job_id"])
    return "⚠️ Vaga ##{action["job_id"]} não encontrada." unless job

    text = AiWriter.new(job).summary
    job.update!(custom_summary: text)
    job.ai_edits.create!(kind: "summary", description: "Resumo gerado pelo Assistente: \"#{text.truncate(160)}\"")
    touch(job)
    "✅ Resumo adaptado com IA — revise em [#{job.title}](/jobs/#{job.id}?panel=ajustar)"
  end

  def cover_letter(action)
    job = find_job(action["job_id"])
    return "⚠️ Vaga ##{action["job_id"]} não encontrada." unless job

    text = AiWriter.new(job).cover_letter
    job.update!(cover_letter: text)
    job.ai_edits.create!(kind: "cover_letter", description: "Carta gerada pelo Assistente: \"#{text.truncate(160)}\"")
    touch(job)
    "✅ Carta gerada — revise em [#{job.title}](/jobs/#{job.id}?panel=carta)"
  end

  def analyze_job(action)
    job = find_job(action["job_id"])
    return "⚠️ Vaga ##{action["job_id"]} não encontrada." unless job

    job.update!(ai_analysis: AiMatcher.new(job).call)
    job.ai_edits.create!(kind: "analysis", description: "Análise gerada pelo Assistente")
    touch(job)
    "✅ Análise de aderência pronta para [#{job.title}](/jobs/#{job.id}?panel=analise):\n\n#{job.ai_analysis}"
  end

  def adapt_job(action)
    job = find_job(action["job_id"])
    return "⚠️ Vaga ##{action["job_id"]} não encontrada." unless job
    return "⚠️ Rode a análise primeiro (analyze_job) para ter sugestões." if job.ai_analysis.blank?

    result = AiAdapter.new(job).call
    return "⚠️ Não consegui aplicar sugestões." unless result&.dig(:changes)&.any?

    job.ai_edits.create!(kind: "adapt", description: result[:changes].join("; "))
    touch(job)
    "✅ Sugestões aplicadas em [#{job.title}](/jobs/#{job.id}?panel=ajustar): #{result[:changes].to_sentence}."
  end

  # Liga/desliga itens específicos do currículo da vaga (experiências, bullets, competências).
  def toggle_items(action)
    job = find_job(action["job_id"])
    return "⚠️ Vaga ##{action["job_id"]} não encontrada." unless job

    keys = ResumeTailor.new(job).toggleable_keys
    changes = []
    Array(action["items"]).each do |item|
      key = item["key"].to_s
      next unless keys.key?(key)

      include = !!item["include"]
      job.overrides = job.overrides.merge(key => include)
      changes << "#{include ? 'incluído' : 'removido'}: #{keys[key][:label]}"
    end
    return "⚠️ Nenhuma chave válida recebida — use as chaves da lista 'Currículo desta vaga'." if changes.empty?

    job.save!
    job.ai_edits.create!(kind: "update", description: "Assistente #{changes.join('; ')}")
    touch(job)
    "✅ Currículo de [#{job.title}](/jobs/#{job.id}) atualizado: #{changes.to_sentence}."
  end

  # Edita o conteúdo do currículo desta vaga: novos bullets, reescrita de bullet,
  # novas entradas (experiência/projeto/formação/certificação) e competências extras.
  # Fica em job.ai_content — não altera o perfil base compartilhado.
  def edit_content(action)
    job = find_job(action["job_id"])
    return "⚠️ Vaga ##{action["job_id"]} não encontrada." unless job

    content = job.ai_content.to_h
    content["rewrites"] ||= {}
    content["bullets"]  ||= []
    content["entries"]  ||= []
    content["skills"]   ||= []
    keys = ResumeTailor.new(job).toggleable_keys
    changes = []

    Array(action["changes"]).each do |change|
      next unless change.is_a?(Hash)

      case change["op"]
      when "add_bullet"
        parent = change["parent_key"].to_s
        text = AiText.clean(change["text"].to_s)
        next unless parent.match?(BULLET_PARENT) && keys.key?(parent) && text.present?

        content["bullets"] << { "parent_key" => parent, "text" => text }
        changes << "novo bullet em #{keys[parent][:label]}"
      when "rewrite_bullet"
        key = change["key"].to_s
        text = AiText.clean(change["text"].to_s)
        next unless keys.key?(key) && key.include?(":b:") && text.present?

        content["rewrites"][key] = text
        changes << "bullet reescrito: #{keys[key][:label].truncate(50)}"
      when "add_entry"
        section = change["section"].to_s
        next unless ENTRY_FIELDS.key?(section)

        item = (change["item"] || {}).slice(*ENTRY_FIELDS[section])
        next if item.values.all? { |v| v.to_s.blank? && v != true && v != false }

        item = item.transform_values { |v| v.is_a?(String) ? AiText.clean(v) : v }
        bullets = Array(change["bullets"]).map { |t| AiText.clean(t.to_s) }.reject(&:blank?)
        content["entries"] << { "section" => section, "item" => item, "bullets" => bullets }
        changes << "nova entrada: #{[item['role'], item['name'], item['degree'], item['company'], item['institution'], item['issuer']].compact_blank.first(2).join(' · ')}"
      when "add_skill"
        Array(change["name"] || change["names"]).each do |name|
          name = AiText.clean(name.to_s)
          next if name.blank? || content["skills"].include?(name)

          content["skills"] << name
          changes << "competência adicionada: #{name}"
        end
      end
    end

    return "⚠️ Nenhuma mudança válida — use ops add_bullet/rewrite_bullet/add_entry/add_skill com chaves da lista 'Currículo desta vaga'." if changes.empty?

    job.update!(ai_content: content)
    job.ai_edits.create!(kind: "update", description: "Assistente: #{changes.to_sentence.truncate(300)}")
    touch(job)
    "✅ Currículo de [#{job.title}](/jobs/#{job.id}) atualizado: #{changes.to_sentence}."
  end

  def update_profile(action)
    profile = Profile.for(action["language"].presence || @settings.language)
    fields = clean_fields(action["fields"].is_a?(Hash) ? action["fields"] : {}).slice(*PROFILE_ATTRS.map(&:to_s))
    unchanged = fields.all? { |k, v| profile.public_send(k).to_s == v.to_s }
    return "ℹ️ Nada mudou — o perfil já está assim." if unchanged

    profile.update!(fields)
    touch(@current_job) if @current_job
    "✅ Perfil (#{profile.language}) atualizado: #{fields.keys.join(', ')}"
  end

  # Marca a vaga como alterada — o controller manda um turbo refresh
  # pra página do usuário atualizar (morph) sem reload manual.
  def touch(job)
    @touched_job_ids << job.id if job
  end

  # Texto que vai pro currículo ou fica salvo: remove marcas de IA.
  def clean_fields(fields)
    fields.transform_values { |v| v.is_a?(String) ? AiText.clean(v, markdown: true) : v }
  end

  def find_job(id)
    Job.find_by(id: id)
  end

  def focus_resume_keys
    ResumeTailor.new(@current_job).toggleable_keys.map do |key, meta|
      "#{key} → #{meta[:included] ? 'visível' : 'oculto'} - #{meta[:label]}"
    end.join("\n")
  end

  # ---------- contexto e protocolo ----------

  def system_prompt
    <<~PROMPT
      Você é o assistente do app "Currículos sob medida", que adapta currículos para vagas.
      Você ajuda o usuário a: cadastrar vagas, adaptar o currículo para uma vaga, gerar resumo
      e carta de apresentação, e atualizar o perfil. Responda em português, direto e útil.
      Se precisar de um dado que falta (ex.: descrição da vaga), pergunte antes de agir.
      NUNCA invente experiências, empresas ou tecnologias que não estejam no perfil.
      IMPORTANTE: "nesse currículo"/"essa vaga" = a vaga em foco — use update_job (custom_summary,
      custom_headline, ai_instructions) ou edit_content/toggle_items com o job_id dela. NÃO use
      update_profile para mudanças num currículo específico: o perfil é a fonte compartilhada e
      a vaga pode ter resumo próprio (custom_summary) que cobre o do perfil.
      update_profile só quando o usuário pedir para mudar o perfil base (afeta todas as vagas).

      SEMPRE responda com um JSON puro (sem markdown em volta) neste formato:
      {"reply": "sua resposta em markdown (negrito, listas, links ok)", "actions": []}
      Na "reply" e em todos os textos: nunca use travessão/en dash, aspas tipográficas ou emojis;
      escreva direto, sem clichês de IA. Você conhece a descrição das vagas abaixo: use para
      responder perguntas sobre elas e sobre o currículo do usuário sem precisar pedir a vaga.

      Ações disponíveis (coloque em "actions" quando o usuário pedir; você pode pedir várias):
      - {"type":"create_job","fields":{"title":"cargo","company":"empresa","url":"link ou null",
        "description":"texto da vaga que o usuário colou","language":"pt|en"}}
      - {"type":"update_job","job_id":ID,"fields":{"status":"salva|aplicada|entrevista|oferta|rejeitada",
        "title":"...","company":"...","notes":"...","custom_headline":"...","custom_summary":"...",
        "ai_instructions":"instruções que a IA deve seguir ao gerar resumo/carta desta vaga"}}
      - {"type":"tailor_summary","job_id":ID} — gera um resumo do currículo adaptado à vaga
      - {"type":"cover_letter","job_id":ID} — gera carta de apresentação para a vaga
      - {"type":"analyze_job","job_id":ID} — roda a análise de aderência perfil×vaga
      - {"type":"adapt_job","job_id":ID} — aplica as sugestões do parecer no currículo da vaga
      - {"type":"toggle_items","job_id":ID,"items":[{"key":"exp:12","include":false}]}
        — liga/desliga itens do currículo da vaga; use SÓ chaves da seção 'Currículo desta vaga'
      - {"type":"edit_content","job_id":ID,"changes":[
          {"op":"add_bullet","parent_key":"exp:12","text":"texto do bullet"},
          {"op":"rewrite_bullet","key":"exp:12:b:UUID","text":"novo texto"},
          {"op":"add_entry","section":"experiences|projects|certifications|educations",
           "item":{"role":"Cargo","company":"Empresa","start_date":"AAAA-MM","end_date":"AAAA-MM",
           "location":"...","description":"...","name":"...","issuer":"...","degree":"...",
           "field":"...","institution":"...","url":"...","skills":["..."]},
           "bullets":["bullet 1"]},
          {"op":"add_skill","names":["Kubernetes","Redis"]}]}
        — adiciona/reescreve conteúdo do currículo da vaga. IMPORTANTE: só adicione experiências,
        projetos ou fatos que o usuário informou ou que já existem no perfil — nunca invente.
        Se o usuário pedir para adicionar algo que não informou, pergunte os detalhes antes.
      - {"type":"update_profile","language":"pt|en","fields":{"summary":"...","headline":"...",
        "full_name":"...","email":"...","phone":"...","location":"...","linkedin":"...",
        "github":"...","website":"..."}}
      Para vaga nova, use job_id da lista abaixo. Se o usuário não informou qual vaga e houver
      várias, pergunte qual. Na "reply", referencie vagas pelo título.

      #{context}
    PROMPT
  end

  def context
    jobs = Job.recent.limit(15)
    job_lines = jobs.map do |job|
      "##{job.id} \"#{job.title}\"#{job.company.present? ? " @ #{job.company}" : ""} [#{job.status}] (#{job.language})\n" \
      "   Descrição: #{job.description.to_s.truncate(800)}\n" \
      "   Instruções IA: #{job.ai_instructions.to_s.truncate(200)}"
    end.join("\n")

    focus = if @current_job
      <<~FOCUS
        \n\n## Vaga em foco (o usuário está olhando ela agora — prefira ela quando o pedido for ambíguo)
        ##{@current_job.id} "#{@current_job.title}" @ #{@current_job.company} [#{@current_job.status}]
        Descrição: #{@current_job.description.to_s.truncate(3000)}
        Resumo atual do currículo: #{(@current_job.custom_summary.presence || '(padrão do perfil)').truncate(500)}
        Último parecer da IA: #{@current_job.ai_analysis.to_s.truncate(1500)}

        ## Currículo desta vaga agora (o que aparece — chave → incluído? - item)
        #{focus_resume_keys}
      FOCUS
    else
      ""
    end

    Setting::LANGUAGES.map do |lang|
      profile = Profile.for(lang)
      <<~CTX
        ## Perfil (#{lang})
        #{profile.full_name} — #{profile.headline}
        Resumo: #{profile.summary.to_s.truncate(600)}
        Experiências: #{profile.experiences.map { |e| "#{e.role} @ #{e.company}" }.join("; ")}
        Competências: #{profile.skills.order(:position).map(&:name).join(", ")}
      CTX
    end.join("\n") + focus +
      "\n\n## Vagas atuais (use o #ID nas ações)\n#{job_lines.presence || '(nenhuma vaga cadastrada)'}"
  end
end
