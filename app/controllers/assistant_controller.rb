# Chat com o Assistente: cria vagas, adapta currículo e edita o perfil
# a partir de linguagem natural (aba "Assistente").
class AssistantController < ApplicationController
  def show
    @messages = ChatMessage.order(:id)
    @ai_ready = LlmClient.available?
  end

  def create
    @job_id = params[:job_id]
    @message = ChatMessage.new(role: "user", content: params.require(:content).to_s.strip)
    if @message.save
      begin
        assistant = Assistant.new(@message.content, job_id: @job_id)
        @reply = ChatMessage.create!(role: "assistant", content: assistant.call)
        @touched_jobs = assistant.touched_job_ids
      rescue LlmClient::Error => e
        @reply = ChatMessage.create!(role: "assistant",
                                     content: "⚠️ #{e.message}\n\nConfigure a IA nas [Configurações](/settings/edit).")
      end
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to assistant_path, status: :see_other }
    end
  end

  def destroy
    ChatMessage.delete_all
    redirect_to assistant_path, notice: "Conversa apagada.", status: :see_other
  end
end
