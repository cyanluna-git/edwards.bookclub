class MeetingAttendance < ApplicationRecord
  belongs_to :meeting
  belongs_to :member

  before_validation :refresh_award_snapshot, if: :should_refresh_award_snapshot?

  validates :reserve_exempt, inclusion: { in: [ true, false ] }
  validates :member_id, uniqueness: { scope: :meeting_id }
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validates :awarded_points, :override_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def effective_awarded_points
    return 0 if reserve_exempt?

    override_points.presence || awarded_points.to_i
  end

  def award_source
    return "reserve_exempt" if reserve_exempt?
    return "manual_override" if override_points.present?
    return "pending" if awarded_points.nil?

    reserve_office_labels_at_award.any? ? "office_policy" : "member_policy"
  end

  def award_source_label
    case award_source
    when "reserve_exempt" then "Exempt"
    when "manual_override" then "Manual override"
    when "office_policy"
      labels = reserve_office_labels_at_award
      labels.any? ? labels.join(", ") : "Privileged office"
    when "member_policy" then awarded_policy_role.presence || "Standard member"
    else "Pending snapshot"
    end
  end

  def refresh_award_snapshot(force: false)
    return unless meeting && member

    result = Reserves::AttendanceAwardResolver.new(attendance: self).call
    snapshot_changed =
      force ||
      awarded_points != result.awarded_points ||
      awarded_policy_role != result.policy_role

    self.awarded_points = result.awarded_points
    self.awarded_policy_role = result.policy_role
    self.awarded_at = Time.current if snapshot_changed
    result
  end

  private

  def should_refresh_award_snapshot?
    return false unless meeting && member

    new_record? ||
      will_save_change_to_member_id? ||
      will_save_change_to_meeting_id? ||
      will_save_change_to_reserve_exempt? ||
      will_save_change_to_override_points?
  end

  def reserve_office_labels_at_award
    return [] unless meeting && member

    member.reserve_office_labels_on(meeting.meeting_at.to_date)
  end
end
