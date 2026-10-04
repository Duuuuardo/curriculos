class Setting < ApplicationRecord
  LANGUAGES = %w[pt en].freeze
  PAPER_SIZES = %w[letter a4].freeze
  ATTRIBUTES = %i[language accent_color paper_size max_bullets max_skills
                  ollama_url ollama_model ai_provider ai_api_key ai_base_url ai_model].freeze

  validates :language, inclusion: { in: LANGUAGES }
  validates :paper_size, inclusion: { in: PAPER_SIZES }
  validates :accent_color, format: { with: /\A#\h{6}\z/ }
  validates :max_bullets, numericality: { only_integer: true, in: 1..12 }
  validates :max_skills, numericality: { only_integer: true, in: 1..60 }
  validates :ollama_url, format: { with: %r{\Ahttps?://} }
  validates :ai_provider, inclusion: { in: LlmClient::PROVIDERS.keys }
  validates :ai_base_url, format: { with: %r{\A(https?://|\z)} }

  def self.current
    first_or_create!
  end

  def as_json(*)
    slice(*ATTRIBUTES)
  end
end
