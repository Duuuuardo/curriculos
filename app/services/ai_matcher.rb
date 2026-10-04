# Parecer qualitativo da IA sobre a aderência do perfil à vaga: nota, pontos fortes,
# lacunas e sugestões de ajuste — sempre sem inventar fatos fora do perfil.
class AiMatcher
  def initialize(job, profile: Profile.for(job.language), settings: Setting.current)
    @job = job
    @profile = profile
    @settings = settings
  end

  def call
    AiText.clean(LlmClient.generate_text(@settings, prompt), markdown: true)
  end

  private

  def prompt
    analysis = JobAnalysis.new(@job, @profile).as_json
    <<~PROMPT
      Você é um recrutador técnico avaliando se um currículo combina com uma vaga.
      Responda em português, formato markdown simples, nesta ordem:
      1. "**Aderência: N/100**" — nota honesta baseada nos requisitos cobertos;
      2. "**Pontos fortes**" — 2 a 4 itens ligando fatos do perfil aos requisitos;
      3. "**Lacunas**" — o que a vaga pede e o perfil não demonstra;
      4. "**Sugestões**" — 3 a 5 ajustes concretos neste currículo, SÓ usando fatos que já existem no perfil
         (reordenar, destacar, reescrever frase, citar tecnologia já usada).

      Seja direto, sem enrolação e sem inventar experiência, número ou tecnologia.
      Nunca use travessão/en dash, aspas tipográficas ou emojis; pode usar **negrito** e listas com -.

      ## Vaga
      Título: #{@job.title}
      Empresa: #{@job.company}
      Descrição: #{@job.description.to_s.truncate(5000)}

      ## Palavras-chave encontradas (automático)
      Cobertas: #{analysis[:matched].join(', ').presence || 'nenhuma'}
      Faltando: #{(analysis[:keywords] - analysis[:matched]).join(', ').presence || 'nenhuma'}

      ## Perfil do candidato
      Nome: #{@profile.full_name}
      Título: #{@profile.headline}
      Resumo: #{@profile.summary}
      Experiências:
      #{experiences_text}
      Competências: #{@profile.skills.map(&:name).join(', ')}
      Formação: #{@profile.educations.map { |e| "#{e.degree} #{e.field} - #{e.institution}" }.join('; ')}
    PROMPT
  end

  def experiences_text
    @profile.experiences.map do |e|
      "- #{e.role} na #{e.company}: #{e.bullets.map { |b| b['text'] }.join('; ')}"
    end.join("\n")
  end
end
