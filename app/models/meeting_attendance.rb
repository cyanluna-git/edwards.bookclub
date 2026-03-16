class MeetingAttendance < ApplicationRecord
  belongs_to :meeting
  belongs_to :member

  validates :reserve_exempt, inclusion: { in: [true, false] }
  validates :member_id, uniqueness: { scope: :meeting_id }
end
