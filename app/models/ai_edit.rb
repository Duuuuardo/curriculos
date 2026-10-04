# Registro do que a IA alterou numa vaga (aba "Ajustar" mostra o histórico).
class AiEdit < ApplicationRecord
  belongs_to :job

  KINDS = %w[summary cover_letter analysis adapt update].freeze

  validates :kind, inclusion: { in: KINDS }

  scope :recent_first, -> { order(id: :desc) }
end
