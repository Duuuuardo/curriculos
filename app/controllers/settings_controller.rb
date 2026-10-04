class SettingsController < ApplicationController
  def edit
    @settings = Setting.current
  end

  def update
    Setting.current.update!(params.require(:settings).permit(*Setting::ATTRIBUTES))
    redirect_to edit_settings_path, notice: "Configurações salvas", status: :see_other
  end
end
