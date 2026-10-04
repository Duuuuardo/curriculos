# Gera textos com a IA configurada usando só fatos do perfil, para não inventar experiência.
class AiWriter
  LANGUAGE_NAMES = { "pt" => "português do Brasil", "en" => "English" }.freeze

  def initialize(job, profile: Profile.for(job.language), settings: Setting.current)
    @job = job
    @profile = profile
    @settings = settings
    @tailor = ResumeTailor.new(job, profile, settings)
  end

  def summary
    generate(<<~PROMPT)
      Você é um especialista em recrutamento. Escreva um resumo profissional para o topo de um currículo,
      em #{language}, com 3 a 4 frases, na primeira pessoa implícita (sem "eu"), direto e sem clichês.
      Destaque as experiências e competências do candidato que mais combinam com a vaga e use naturalmente
      as palavras-chave que o candidato realmente possui. NÃO invente nada que não esteja no perfil.
      Responda apenas com o texto do resumo, sem título e sem aspas.
      #{ANTI_SLOP}

      #{context}
    PROMPT
  end

  def cover_letter
    generate(<<~PROMPT)
      Você é um especialista em recrutamento. Escreva uma carta de apresentação curta (até 250 palavras), em #{language},
      para o candidato abaixo se candidatar à vaga. Tom profissional e humano, 3 parágrafos, conectando experiências
      concretas do perfil aos requisitos da vaga. NÃO invente fatos, números ou empresas que não estejam no perfil.
      Responda apenas com o texto da carta.
      #{ANTI_SLOP}

      #{context}
    PROMPT
  end

  ANTI_SLOP = <<~RULES.freeze
    Regras de estilo obrigatórias (texto de currículo, não pode parecer gerado por IA):
    - texto PURO: sem markdown, sem asteriscos, sem hashtags, sem emojis;
    - nunca use travessão nem en dash; use hífen comum ou reescreva a frase;
    - nunca use aspas tipográficas curvas; se precisar, use aspas retas;
    - proibidos clichês e fórmulas de IA: "profissional apaixonado", "comprovada capacidade",
      "alavancar", "trajetória de sucesso", "dinâmico e proativo", "sinergia";
    - frases diretas com verbos concretos e fatos, nada de adjetivos vazios.
  RULES

  private

  def language
    LANGUAGE_NAMES.fetch(@job.language)
  end

  def context
    analysis = @tailor.analysis.as_json
    <<~CONTEXT
      ## Vaga
      Título: #{@job.title}
      Empresa: #{@job.company}
      Descrição:
      #{@job.description.truncate(6000)}

      ## Palavras-chave da vaga que o candidato possui
      #{analysis[:matched].join(', ').presence || '(nenhuma)'}

      ## Perfil do candidato
      Nome: #{@profile.full_name}
      Título: #{@profile.headline}
      Resumo atual: #{@profile.summary}
      Experiências:
      #{experiences_text}
      Projetos:
      #{@profile.projects.map { |p| "- #{p.name}: #{p.description} #{p.bullets.map { |b| b['text'] }.join('; ')}" }.join("\n")}
      Competências: #{@profile.skills.map(&:name).join(', ')}
      Formação: #{@profile.educations.map { |e| "#{e.degree} #{e.field} - #{e.institution}" }.join('; ')}
      Idiomas: #{@profile.languages.map { |l| "#{l.name} (#{l.level})" }.join(', ')}
      #{instructions}
    CONTEXT
  end

  # Instruções livres que o usuário escreveu para esta vaga ("Instruções para a IA").
  def instructions
    return "" if @job.ai_instructions.blank?

    "## Instruções do candidato (priorize, mas sem inventar fatos)\n#{@job.ai_instructions.truncate(1500)}"
  end

  def experiences_text
    @profile.experiences.map do |e|
      period = [ e.start_date, e.current ? "atual" : e.end_date ].compact_blank.join(" a ")
      "- #{e.role} na #{e.company} (#{period}): #{e.bullets.map { |b| b['text'] }.join('; ')}"
    end.join("\n")
  end

  def generate(prompt)
    AiText.clean(LlmClient.generate_text(@settings, prompt))
  end
end
