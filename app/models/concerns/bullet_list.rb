module BulletList
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_lists
  end

  private

  def normalize_lists
    self.bullets = Array(bullets).filter_map do |bullet|
      bullet = bullet.to_h.stringify_keys
      text = bullet["text"].to_s.strip
      next if text.empty?

      { "id" => bullet["id"].presence || SecureRandom.uuid, "text" => text }
    end
    self.skills = Array(skills).map { |skill| skill.to_s.strip }.reject(&:empty?).uniq
  end
end
