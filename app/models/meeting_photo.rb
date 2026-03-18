class MeetingPhoto < ApplicationRecord
  belongs_to :meeting

  has_one_attached :image

  normalizes :source_url, :file_path, :caption, with: ->(value) { value&.strip }

  validates :sort_order, numericality: { only_integer: true }
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validate :asset_reference_present

  private

  def asset_reference_present
    return if image.attached? || source_url.present? || file_path.present?

    errors.add(:base, "Photo needs an uploaded image, source URL, or file path")
  end
end
