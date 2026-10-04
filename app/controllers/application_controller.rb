class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  rescue_from ActiveRecord::RecordNotFound do
    redirect_to root_path, alert: "Não encontrado"
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    redirect_back fallback_location: root_path, alert: error.record.errors.full_messages.to_sentence
  end

  rescue_from ActionController::ParameterMissing, ArgumentError do |error|
    redirect_back fallback_location: root_path, alert: error.message
  end
end
