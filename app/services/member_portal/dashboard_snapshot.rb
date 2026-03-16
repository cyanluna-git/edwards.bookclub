module MemberPortal
  class DashboardSnapshot
    Result = Struct.new(
      :member,
      :fiscal_period,
      :attendance_reserve_total,
      :purchased_book_total,
      :additional_payment_total,
      :balance,
      :attendance_count,
      :book_request_count,
      :recent_meetings,
      :recent_book_requests,
      keyword_init: true
    )

    def initialize(member:, fiscal_period: nil)
      @member = member
      @fiscal_period = fiscal_period || FiscalPeriod.find_by(active: true)
    end

    def call
      return empty_result unless @member

      attendances = MeetingAttendance.includes(:meeting).where(member: @member, reserve_exempt: false)
      attendances = attendances.joins(:meeting).where(meetings: { fiscal_period_id: @fiscal_period.id }) if @fiscal_period
      requests = BookRequest.where(member: @member)
      requests = requests.where(fiscal_period_id: @fiscal_period.id) if @fiscal_period

      attendance_reserve_total = attendances.sum { |attendance| reserve_points_for(attendance) }
      purchased_book_total = requests.sum(:price).to_d
      additional_payment_total = requests.sum(:additional_payment).to_d

      Result.new(
        member: @member,
        fiscal_period: @fiscal_period,
        attendance_reserve_total:,
        purchased_book_total:,
        additional_payment_total:,
        balance: attendance_reserve_total - purchased_book_total + additional_payment_total,
        attendance_count: attendances.size,
        book_request_count: requests.count,
        recent_meetings: Meeting.joins(:meeting_attendances).where(meeting_attendances: { member_id: @member.id }).order(meeting_at: :desc).distinct.limit(5),
        recent_book_requests: requests.order(requested_on: :desc, created_at: :desc).limit(5)
      )
    end

    private

    def reserve_points_for(attendance)
      meeting_date = attendance.meeting.meeting_at.to_date
      policy = ReservePolicy
        .where(member_role: attendance.member.reserve_policy_role)
        .where("effective_from <= ? AND (effective_to IS NULL OR effective_to >= ?)", meeting_date, meeting_date)
        .order(effective_from: :desc)
        .first

      policy&.attendance_points.to_i
    end

    def empty_result
      Result.new(
        member: nil,
        fiscal_period: @fiscal_period,
        attendance_reserve_total: 0.to_d,
        purchased_book_total: 0.to_d,
        additional_payment_total: 0.to_d,
        balance: 0.to_d,
        attendance_count: 0,
        book_request_count: 0,
        recent_meetings: [],
        recent_book_requests: []
      )
    end
  end
end
