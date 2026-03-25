module Reserves
  class AttendanceAwardResolver
    Result = Struct.new(
      :meeting_date,
      :policy_role,
      :awarded_points,
      :effective_points,
      :office_labels,
      :source,
      keyword_init: true
    )

    def initialize(attendance:)
      @attendance = attendance
    end

    def call
      return exempt_result if @attendance.reserve_exempt?

      meeting_date = @attendance.meeting&.meeting_at&.to_date || Date.current
      office_labels = @attendance.member&.reserve_office_labels_on(meeting_date).to_a
      policy_role = @attendance.member&.reserve_policy_role_on(meeting_date) || "정회원"
      awarded_points = resolved_policy_points(policy_role, meeting_date)
      effective_points = @attendance.override_points.presence || awarded_points
      source = @attendance.override_points.present? ? "manual_override" : (office_labels.any? ? "office_policy" : "member_policy")

      Result.new(
        meeting_date:,
        policy_role:,
        awarded_points:,
        effective_points:,
        office_labels:,
        source:
      )
    end

    private

    def exempt_result
      Result.new(
        meeting_date: @attendance.meeting&.meeting_at&.to_date,
        policy_role: "reserve_exempt",
        awarded_points: 0,
        effective_points: 0,
        office_labels: [],
        source: "reserve_exempt"
      )
    end

    def resolved_policy_points(policy_role, meeting_date)
      policy = ReservePolicy
        .where(member_role: policy_role)
        .where("effective_from <= ? AND (effective_to IS NULL OR effective_to >= ?)", meeting_date, meeting_date)
        .order(effective_from: :desc)
        .first

      policy&.attendance_points.to_i
    end
  end
end
