class ProfilesController < ApplicationController
  before_action :set_profile

  def edit
  end

  def update
    ProfileSync.new(@profile).call(profile_params)
    redirect_to profile_path(@profile.language), notice: "Perfil salvo!", status: :see_other
  end

  def copy
    source = Profile.for(params.require(:from))
    raise ArgumentError, "Escolha idiomas diferentes" if source == @profile

    @profile.copy_from!(source)
    redirect_to profile_path(@profile.language), notice: "Perfil copiado. Agora é só traduzir os textos!",
                status: :see_other
  end

  def import
    result = ResumeImport.call(params.require(:resume))
    counts = ProfileImporter.new(@profile).merge(result.data)

    parts = [ (counts[:experiences].positive? ? "#{counts[:experiences]} experiência(s)" : nil),
              (counts[:projects].positive? ? "#{counts[:projects]} projeto(s)" : nil),
              (counts[:skills].positive? ? "#{counts[:skills]} competência(s)" : nil),
              (counts[:educations].positive? ? "#{counts[:educations]} formação" : nil),
              (counts[:languages].positive? ? "#{counts[:languages]} idioma(s)" : nil),
              (counts[:certifications].positive? ? "#{counts[:certifications]} certificação(ões)" : nil),
              (counts[:fields].positive? ? "#{counts[:fields]} dado(s) de contato" : nil) ].compact

    detail = parts.any? ? parts.join(", ") : "nada novo — o perfil já tinha esses dados"
    via = result.ai_used ? " com ajuda da IA" : (result.source == :linkedin ? " (PDF do LinkedIn)" : "")
    redirect_to profile_path(@profile.language),
                notice: "PDF importado#{via}: #{detail}. Confira e ajuste abaixo.", status: :see_other
  rescue ResumeImport::Error, ActionController::ParameterMissing => e
    redirect_to profile_path(@profile.language), alert: e.message, status: :see_other
  end

  private

  def set_profile
    @profile = Profile.for(params[:language])
  end

  # O formulário envia cada seção como um hash indexado (profile[experiences][KEY][campo]);
  # aqui ele vira um array na ordem em que os itens aparecem na página.
  def profile_params
    permitted = params.require(:profile).permit!.to_h.deep_symbolize_keys
    Profile::SECTIONS.each_key do |section|
      value = permitted[section]
      permitted[section] = value.is_a?(Hash) ? value.values : Array(value)
    end
    permitted
  end
end
