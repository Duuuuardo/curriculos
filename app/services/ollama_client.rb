require "net/http"

# Cliente mínimo para o Ollama (https://ollama.com), que roda modelos de IA localmente e de graça.
class OllamaClient
  class Error < StandardError; end

  # Resolve o modelo configurado (ou o primeiro instalado) e gera texto.
  def self.generate_text(settings, prompt)
    client = new(settings.ollama_url)
    model = settings.ollama_model.presence || client.models.first
    raise Error, "Nenhum modelo instalado no Ollama. Rode por exemplo: ollama pull llama3.2" unless model

    client.generate(model: model, prompt: prompt)
  end

  def self.available?(settings = Setting.current)
    new(settings.ollama_url).models.any?
  rescue Error
    false
  end

  def initialize(base_url)
    @base_url = base_url.to_s.chomp("/")
  end

  def models
    get("/api/tags").fetch("models", []).map { |model| model["name"] }
  end

  def generate(model:, prompt:)
    chat(model: model, messages: [ { role: "user", content: prompt } ])
  end

  def chat(model:, messages:)
    post("/api/chat", { model: model, stream: false, options: { temperature: 0.4 },
                        messages: messages.map { |m| { role: m[:role].to_s, content: m[:content].to_s } } })
      .dig("message", "content").to_s.strip
  end

  private

  def get(path)
    request(Net::HTTP::Get.new(uri(path)), read_timeout: 5)
  end

  def post(path, body)
    req = Net::HTTP::Post.new(uri(path), "Content-Type" => "application/json")
    req.body = body.to_json
    request(req, read_timeout: 300)
  end

  def request(req, read_timeout:)
    target = req.uri
    response = Net::HTTP.start(target.host, target.port, use_ssl: target.scheme == "https",
                               open_timeout: 2, read_timeout: read_timeout) { |http| http.request(req) }
    raise Error, "Ollama respondeu #{response.code}: #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError => e
    raise Error, "Não consegui falar com o Ollama em #{@base_url} (#{e.class.name.demodulize}). Ele está rodando?"
  rescue JSON::ParserError
    raise Error, "Resposta inválida do Ollama"
  end

  def uri(path)
    URI.parse("#{@base_url}#{path}")
  end
end
