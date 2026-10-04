# Exporta/importa todos os dados em JSON, preservando os ids (as escolhas por vaga dependem deles).
class Backup
  VERSION = 2

  def self.export
    {
      version: VERSION,
      exported_at: Time.current.iso8601,
      profiles: Profile.order(:language).map(&:as_json),
      jobs: Job.order(:id).map(&:as_json),
      settings: Setting.current.as_json
    }
  end

  def self.import(data)
    data = data.to_h.deep_stringify_keys
    profiles = data["profiles"] || [ data["profile"] ].compact
    raise ArgumentError, "Backup inválido" unless profiles.is_a?(Array) && profiles.any? && profiles.all?(Hash)

    ActiveRecord::Base.transaction do
      Job.delete_all
      Profile.destroy_all
      Setting.delete_all

      profiles.each { |profile| import_profile(profile) }

      Array(data["jobs"]).each do |job|
        Job.create!(job.to_h.slice("id", *Job::ATTRIBUTES.map(&:to_s), "created_at", "updated_at"))
      end

      Setting.create!(data["settings"].to_h.slice(*Setting::ATTRIBUTES.map(&:to_s)))
    end
  end

  def self.import_profile(data)
    profile = Profile.create!(data.slice(*Profile::FIELDS.map(&:to_s)).merge("language" => data["language"].presence || "pt"))
    Profile::SECTIONS.each do |section, attributes|
      Array(data[section.to_s]).each_with_index do |item, position|
        attrs = item.to_h.slice("id", *attributes.map(&:to_s)).merge("position" => position)
        profile.public_send(section).create!(attrs)
      end
    end
  end
  private_class_method :import_profile

  def self.sample
    JSON.parse(Rails.root.join("db/sample.json").read)
  end
end
