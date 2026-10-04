# Mensagens da conversa com o Assistente (aba "Assistente").
class ChatMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :history, ->(count = 30) { order(:id).last(count) }
end
