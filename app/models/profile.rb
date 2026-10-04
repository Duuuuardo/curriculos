class Profile < ApplicationRecord
  SECTIONS = {
    experiences: %i[company role location start_date end_date current bullets skills],
    educations: %i[institution degree field start_date end_date description],
    skills: %i[name category level],
    projects: %i[name url description bullets skills],
    languages: %i[name level],
    certifications: %i[name issuer date url]
  }.freeze

  FIELDS = %i[full_name headline email phone location linkedin github website summary].freeze

  SECTIONS.each_key do |section|
    has_many section, -> { order(:position, :id) }, dependent: :destroy
  end

  validates :language, inclusion: { in: Setting::LANGUAGES }, uniqueness: true

  def self.for(language)
    language = language.to_s
    find_or_create_by!(language: Setting::LANGUAGES.include?(language) ? language : Setting::LANGUAGES.first)
  end

  def blank_profile?
    FIELDS.all? { |field| public_send(field).blank? } && SECTIONS.each_key.none? { |section| public_send(section).exists? }
  end

  def copy_from!(source)
    transaction do
      SECTIONS.each_key { |section| public_send(section).destroy_all }
      update!(source.slice(*FIELDS))
      SECTIONS.each do |section, attributes|
        source.public_send(section).each do |record|
          public_send(section).create!(record.slice(:position, *attributes))
        end
      end
    end
    reload
  end

  def as_json(*)
    { language: language }.merge(FIELDS.index_with { |field| public_send(field) }).merge(
      SECTIONS.to_h do |section, attributes|
        [ section, public_send(section).map { |record| record.slice(:id, *attributes) } ]
      end
    )
  end
end
