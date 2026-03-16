class Meeting < ApplicationRecord
  belongs_to :fiscal_period, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :meeting_attendances, dependent: :delete_all
  has_many :members, through: :meeting_attendances
  has_many :meeting_photos, dependent: :delete_all

  after_commit :refresh_attendance_awards_for_meeting_date_change, if: :saved_change_to_meeting_at?

  normalizes :title, :legacy_title, :location, with: ->(value) { value&.strip }

  scope :ordered_recent, -> { order(meeting_at: :desc, id: :desc) }

  validates :title, :meeting_at, presence: true
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validates :reserve_exempt_default, inclusion: { in: [true, false] }

  def attendance_count
    meeting_attendances.size
  end

  private

  def refresh_attendance_awards_for_meeting_date_change
    meeting_attendances.includes(:member).find_each do |attendance|
      attendance.refresh_award_snapshot(force: true)
      attendance.save! if attendance.changed?
    end
  end
end
