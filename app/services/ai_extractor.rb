require "json"

# Extrai dados estruturados de textos livres usando o Ollama.
# Usado para interpretar PDFs de currículo fora do padrão LinkedIn e para
# preencher título/empresa/idioma ao colar a descrição de uma vaga.
class AiExtractor
  def initialize(settings: Setting.current)
    @settings = settings
  end

  # Currículo em texto puro → hash no formato do Profile, ou nil se a IA não respondeu.
  def resume(text)
    parsed = ask(<<~PROMPT)
      Você é um extrator de dados. Leia o texto de um currículo e devolva APENAS um JSON válido
      (sem markdown, sem comentários) com esta estrutura exata:

      {
        "full_name": "", "headline": "", "email": "", "phone": "", "location": "",
        "linkedin": "", "github": "", "website": "", "summary": "",
        "experiences": [{"company": "", "role": "", "location": "", "start_date": "YYYY-MM",
                         "end_date": "YYYY-MM ou null", "current": false,
                         "bullets": ["frase"], "skills": ["tecnologia"]}],
        "educations": [{"institution": "", "degree": "", "field": "",
                        "start_date": "YYYY-MM ou null", "end_date": "YYYY-MM ou null"}],
        "skills": [{"name": "", "category": "categoria ou null", "level": "nível ou null"}],
        "projects": [{"name": "", "url": "", "description": "", "bullets": ["frase"], "skills": []}],
        "languages": [{"name": "", "level": ""}],
        "certifications": [{"name": "", "issuer": "", "date": "YYYY-MM ou null", "url": ""}]
      }

      Regras: extraia só o que está no texto, sem inventar; datas em YYYY-MM (mês com 2 dígitos);
      cada tópico/atividade vira um item de "bullets"; campos ausentes ficam "" ou null.

      TEXTO DO CURRÍCULO:
      #{text.truncate(14_000)}
    PROMPT
    parsed.is_a?(Hash) ? parsed : nil
  end

  # Descrição de vaga colada → {"title", "company", "url", "language"} ou nil.
  def job(text)
    parsed = ask(<<~PROMPT)
      Extraia os dados de um anúncio de emprego e devolva APENAS um JSON válido (sem markdown) assim:
      {"title": "cargo exato da vaga", "company": "nome da empresa", "url": "link da vaga ou null",
       "language": "pt ou en — idioma predominante do texto"}

      Regras: use o título do CARGO (não o da empresa); se não achar empresa ou url, use null;
      responda somente o JSON.

      TEXTO DA VAGA:
      #{text.truncate(8_000)}
    PROMPT
    return nil unless parsed.is_a?(Hash)

    parsed.transform_keys { |key| key.to_s.underscore.to_sym }.slice(:title, :company, :url, :language)
  end

  private

  def ask(prompt)
    text = LlmClient.generate_text(@settings, prompt)
    JSON.parse(text[/\{.*\}/m].to_s)
  rescue LlmClient::Error, JSON::ParserError
    nil
  end
end
