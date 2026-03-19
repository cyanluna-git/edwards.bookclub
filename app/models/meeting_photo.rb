class MeetingPhoto < ApplicationRecord
  belongs_to :meeting

  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_limit: [200, 150], format: :jpeg, saver: { quality: 80 }
    attachable.variant :medium, resize_to_limit: [800, 600], format: :jpeg, saver: { quality: 85 }
  end

  normalizes :source_url, :file_path, :caption, with: ->(value) { value&.strip }

  validates :sort_order, numericality: { only_integer: true }
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validate :asset_reference_present

  after_commit :compress_original, on: %i[create update], if: -> { image.attached? }

  private

  def asset_reference_present
    return if image.attached? || source_url.present? || file_path.present?

    errors.add(:base, "Photo needs an uploaded image, source URL, or file path")
  end

  def compress_original
    return unless image.blob.content_type&.start_with?("image/")
    return if image.blob.byte_size < 500.kilobytes

    image.blob.open do |tempfile|
      processed = ImageProcessing::Vips
        .source(tempfile.path)
        .resize_to_limit(1920, 1920)
        .convert("jpeg")
        .saver(quality: 85)
        .call

      image.attach(
        io: File.open(processed.path),
        filename: image.blob.filename.to_s.sub(/\.\w+$/, ".jpg"),
        content_type: "image/jpeg"
      )
    end
  rescue => e
    Rails.logger.warn("[MeetingPhoto] Image compression failed for ##{id}: #{e.message}")
  end
end
