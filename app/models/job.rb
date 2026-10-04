class Job < ApplicationRecord
  STATUSES = %w[salva aplicada entrevista oferta rejeitada].freeze
  ATTRIBUTES = %i[
    title company url description language status notes extra_keywords ignored_keywords overrides
    custom_headline custom_summary cover_letter ai_content
  ].freeze

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :language, inclusion: { in: Setting::LANGUAGES }

  has_many :ai_edits, -> { order(id: :desc) }, dependent: :destroy

  before_validation :normalize_lists
  before_validation :detect_language, if: -> { language.blank? }

  scope :recent, -> { order(updated_at: :desc) }

  def as_json(options = {})
    slice(:id, *ATTRIBUTES, :created_at, :updated_at).merge(options.fetch(:extra, {}))
  end

  private

  def normalize_lists
    self.extra_keywords = clean_list(extra_keywords)
    self.ignored_keywords = clean_list(ignored_keywords)
    self.overrides = overrides.to_h.transform_keys(&:to_s).transform_values { |value| ActiveModel::Type::Boolean.new.cast(value) }
    self.ai_content = ai_content.to_h
  end

  def detect_language
    self.language = LanguageDetector.detect(description) || Setting.current.language
  end

  def clean_list(list)
    Array(list).map { |item| item.to_s.strip }.reject(&:empty?).uniq(&:downcase)
  end
end
