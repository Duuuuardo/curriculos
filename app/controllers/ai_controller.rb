class AiController < ApplicationController
  def status
    @kind = params[:kind].to_s
    @job = Job.find_by(id: params[:job_id])
    @available, @models = probe
    render layout: false
  end

  def models
    @current = params[:current].to_s
    @provider = params[:provider].presence_in(LlmClient::PROVIDERS.keys) || Setting.current.ai_provider
    @available, @models = probe(@provider)
    render layout: false
  end

  def test
    Setting.current.update!(params.require(:settings).permit(*Setting::ATTRIBUTES)) if params[:settings]

    label = LlmClient.provider_label
    available, models = probe
    flash[available ? :notice : :alert] =
      if available
        "#{label} conectado! Modelos: #{models.first(8).join(', ').presence || 'nenhum encontrado'}"
      else
        "Não consegui conectar ao #{label}. Confira provedor, URL, chave e modelo."
      end
    redirect_to edit_settings_path, status: :see_other
  end

  def generate
    job = Job.find(params[:id])
    writer = AiWriter.new(job)
    summary = params[:kind] == "summary"
    text = summary ? writer.summary : writer.cover_letter
    job.update!(summary ? { custom_summary: text } : { cover_letter: text })
    job.ai_edits.create!(kind: summary ? "summary" : "cover_letter",
                         description: "#{summary ? 'Resumo' : 'Carta'} gerado por IA: \"#{text.truncate(160)}\"")
    redirect_to job_path(job, panel: summary ? "ajustar" : "carta", anchor: "panel"),
                notice: "Texto gerado! Revise antes de enviar.", status: :see_other
  rescue LlmClient::Error => e
    redirect_to job_path(job, panel: params[:panel].presence, anchor: "panel"), alert: e.message, status: :see_other
  end

  # Usado pelo formulário de nova vaga: lê a descrição colada e devolve
  # título/empresa/link/idioma para o Stimulus preencher os campos.
  def extract_job
    data = AiExtractor.new.job(params[:description].to_s)
    if data
      data[:language] = LanguageDetector.detect(params[:description].to_s) ||
                        data[:language].presence_in(Setting::LANGUAGES) || Setting.current.language
      render json: data
    else
      render json: { error: "IA indisponível — configure um provedor nas Configurações." },
             status: :service_unavailable
    end
  end

  # Parecer qualitativo da IA sobre a aderência perfil × vaga (opcional).
  def match
    job = Job.find(params[:id])
    job.update!(ai_analysis: AiMatcher.new(job).call)
    job.ai_edits.create!(kind: "analysis", description: "Análise de aderência gerada")
    redirect_to job_path(job, panel: "analise", anchor: "panel"), notice: "Análise da IA pronta!", status: :see_other
  rescue LlmClient::Error => e
    redirect_to job_path(job, panel: "analise", anchor: "panel"), alert: e.message, status: :see_other
  end

  # Aplica as sugestões do parecer da IA no currículo desta vaga (headline, resumo, toggles).
  def adapt
    job = Job.find(params[:id])
    result = AiAdapter.new(job).call
    if result&.dig(:changes)&.any?
      job.ai_edits.create!(kind: "adapt", description: result[:changes].join("; "))
      notice = "Aplicado: #{result[:changes].to_sentence}.#{result[:note].present? ? " #{result[:note]}" : ''}"
      redirect_to job_path(job, panel: "ajustar", anchor: "panel"), notice: notice, status: :see_other
    else
      redirect_to job_path(job, panel: "analise", anchor: "panel"),
                  alert: "Nenhuma sugestão aplicável — gere a análise primeiro ou ajuste manualmente.", status: :see_other
    end
  rescue LlmClient::Error => e
    redirect_to job_path(job, panel: "analise", anchor: "panel"), alert: e.message, status: :see_other
  end

  private

  def probe(provider = nil)
    settings = Setting.current
    if provider && provider != settings.ai_provider
      settings = settings.dup
      settings.ai_provider = provider
    end
    [ true, LlmClient.new(settings).models ]
  rescue LlmClient::Error
    [ false, [] ]
  end
end
