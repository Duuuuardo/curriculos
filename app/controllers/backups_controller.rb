class BackupsController < ApplicationController
  def show
    send_data JSON.pretty_generate(Backup.export), filename: "curriculos-backup-#{Date.current}.json",
                                                 type: "application/json"
  end

  def create
    Backup.import(backup_data)
    redirect_to edit_settings_path, notice: "Backup importado!", status: :see_other
  end

  def sample
    Backup.import(Backup.sample)
    redirect_to edit_settings_path, notice: "Dados de exemplo carregados", status: :see_other
  end

  private

  def backup_data
    payload = params.require(:backup)
    payload = payload.read if payload.respond_to?(:read)
    payload.is_a?(String) ? JSON.parse(payload) : payload
  end
end
