require "net/http"

# Camada de acesso aos provedores de IA. Hoje suporta:
# - "ollama"    → Ollama local (grátis)
# - "openai"    → OpenAI e qualquer API compatível (OpenRouter, Groq, Together, LM Studio...)
# - "anthropic" → Claude (API Messages)
# - "gemini"    → Google Gemini (API generateContent)
#
# Uso: LlmClient.generate_text(settings, prompt) ou LlmClient.chat(settings, messages: [...])
class LlmClient
  class Error < StandardError; end

  PROVIDERS = {
    "ollama" => "Ollama (local, grátis)",
    "openai" => "OpenAI / compatível (OpenRouter, Groq, LM Studio...)",
    "anthropic" => "Anthropic (Claude)",
    "gemini" => "Google Gemini"
  }.freeze

  DEFAULT_BASE_URLS = {
    "openai" => "https://api.openai.com/v1",
    "anthropic" => "https://api.anthropic.com",
    "gemini" => "https://generativelanguage.googleapis.com"
  }.freeze

  # Usados quando o usuário não escolhe um modelo nem há lista disponível.
  DEFAULT_MODELS = {
    "openai" => "gpt-4o-mini",
    "anthropic" => "claude-haiku-4-5",
    "gemini" => "gemini-2.0-flash"
  }.freeze

  MAX_TOKENS = 4096

  def self.generate_text(settings, prompt)
    new(settings).chat([ { role: "user", content: prompt } ])
  end

  def self.chat(settings, messages:)
    new(settings).chat(messages)
  end

  def self.models(settings)
    new(settings).models
  end

  def self.available?(settings = Setting.current)
    new(settings).models.any?
  rescue Error
    false
  end

  def self.provider_label(settings = Setting.current)
    PROVIDERS.fetch(settings.ai_provider, settings.ai_provider)
  end

  def initialize(settings)
    @settings = settings
  end

  # messages: [{ role: "system"|"user"|"assistant", content: "..." }]
  def chat(messages)
    case provider
    when "ollama" then ollama_chat(messages)
    when "openai" then openai_chat(messages)
    when "anthropic" then anthropic_chat(messages)
    when "gemini" then gemini_chat(messages)
    else raise Error, "Provedor de IA desconhecido: #{provider}"
    end
  end

  def models
    case provider
    when "ollama"
      OllamaClient.new(@settings.ollama_url).models
    when "openai"
      request(:get, "#{base_url}/models", headers: auth_headers, read_timeout: 10)
        .fetch("data", []).map { |m| m["id"] }.compact.sort
    when "anthropic"
      request(:get, "#{base_url}/v1/models?limit=100", headers: anthropic_headers, read_timeout: 10)
        .fetch("data", []).map { |m| m["id"] }.compact.sort
    when "gemini"
      request(:get, "#{base_url}/v1beta/models?key=#{escaped_key}", read_timeout: 10)
        .fetch("models", []).map { |m| m["name"].to_s.sub("models/", "") }
        .select { |name| name.include?("gemini") }.sort
    else []
    end
  rescue OllamaClient::Error => e
    raise Error, e.message
  end

  # Modelo efetivo: escolha do usuário → primeiro modelo de chat disponível → default.
  def model_name
    @model_name ||= begin
      explicit = provider == "ollama" ? @settings.ollama_model : @settings.ai_model
      explicit.presence || chat_models.first.presence || DEFAULT_MODELS[provider].presence ||
        raise(Error, "Nenhum modelo configurado. Escolha um nas Configurações.")
    end
  end

  private

  NON_CHAT_MODELS = /whisper|guard|orpheus|tts|embed|safeguard|allam|moderation/i.freeze

  def chat_models
    list = models.reject { |name| name.match?(NON_CHAT_MODELS) }
    list.presence || models
  end

  def provider
    @settings.ai_provider.presence_in(PROVIDERS.keys) || "ollama"
  end

  def base_url
    (@settings.ai_base_url.presence || DEFAULT_BASE_URLS[provider]).to_s.chomp("/")
  end

  def api_key
    @settings.ai_api_key.to_s.strip
  end

  def escaped_key
    URI.encode_www_form_component(api_key)
  end

  def auth_headers
    api_key.present? ? { "Authorization" => "Bearer #{api_key}" } : {}
  end

  def anthropic_headers
    { "x-api-key" => api_key, "anthropic-version" => "2023-06-01" }
  end

  # ---------- providers ----------

  def ollama_chat(messages)
    model = model_name
    OllamaClient.new(@settings.ollama_url).chat(model: model, messages: messages)
  rescue OllamaClient::Error => e
    raise Error, e.message
  end

  def openai_chat(messages)
    data = request(:post, "#{base_url}/chat/completions", headers: auth_headers, body: {
      model: model_name, temperature: 0.4,
      messages: messages.map { |m| { role: m[:role].to_s, content: m[:content].to_s } }
    })
    message = data.dig("choices", 0, "message") || {}
    # Modelos de raciocínio (ex.: gpt-oss) podem devolver a resposta em reasoning_content
    content = message["content"].presence || message["reasoning_content"].to_s
    raise Error, "#{provider_label} respondeu vazio — tente de novo ou troque o modelo." if content.strip.empty?

    content.strip
  end

  def anthropic_chat(messages)
    system, conversation = split_system(messages)
    body = { model: model_name, max_tokens: MAX_TOKENS, temperature: 0.4, messages: conversation }
    body[:system] = system if system.present?
    data = request(:post, "#{base_url}/v1/messages", headers: anthropic_headers, body: body)
    data.fetch("content", []).map { |part| part["text"] }.join.strip
  end

  def gemini_chat(messages)
    system, conversation = split_system(messages)
    contents = conversation.map do |m|
      { role: m[:role].to_s == "assistant" ? "model" : "user",
        parts: [ { text: m[:content].to_s } ] }
    end
    body = { contents: contents, generationConfig: { temperature: 0.4, maxOutputTokens: MAX_TOKENS } }
    body[:systemInstruction] = { parts: [ { text: system } ] } if system.present?
    data = request(:post, "#{base_url}/v1beta/models/#{model_name}:generateContent?key=#{escaped_key}", body: body)
    data.dig("candidates", 0, "content", "parts").to_a.map { |part| part["text"] }.join.strip
  end

  def split_system(messages)
    system = messages.select { |m| m[:role].to_s == "system" }.map { |m| m[:content].to_s }.join("\n\n")
    conversation = messages.reject { |m| m[:role].to_s == "system" }
                           .map { |m| { role: m[:role].to_s == "assistant" ? "assistant" : "user",
                                        content: m[:content].to_s } }
    [ system, conversation ]
  end

  # ---------- http ----------

  def request(verb, url, headers: {}, body: nil, read_timeout: 300)
    uri = URI.parse(url)
    req = verb == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
    headers.each { |key, value| req[key] = value }
    if body
      req["Content-Type"] = "application/json"
      req.body = body.to_json
    end
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                               open_timeout: 6, read_timeout: read_timeout) { |http| http.request(req) }
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "#{provider_label} respondeu #{response.code}: #{response.body.to_s.truncate(300)}"
    end

    JSON.parse(response.body)
  rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError => e
    raise Error, "Não consegui falar com #{provider_label} (#{e.class.name.demodulize}). Confira URL e chave."
  rescue JSON::ParserError
    raise Error, "Resposta inválida de #{provider_label}"
  end

  def provider_label
    self.class.provider_label(@settings)
  end
end
