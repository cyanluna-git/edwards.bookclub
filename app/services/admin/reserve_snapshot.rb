module Admin
  class ReserveSnapshot
    Result = Struct.new(
      :fiscal_period,
      :attendance_reserve_total,
      :purchased_book_total,
      :additional_payment_total,
      :balance,
      :attendance_count,
      :purchase_count,
      keyword_init: true
    )

    def initialize(fiscal_period: nil)
      @fiscal_period = fiscal_period || FiscalPeriod.find_by(active: true)
    end

    def call
      return empty_result unless @fiscal_period

      attendances = MeetingAttendance
        .includes(:member, :meeting)
        .joins(:meeting)
        .where(meetings: { fiscal_period_id: @fiscal_period.id })
        .where(reserve_exempt: false)

      attendance_reserve_total = attendances.sum { |attendance| reserve_points_for(attendance) }
      requests = BookRequest.where(fiscal_period_id: @fiscal_period.id)

      purchased_book_total = requests.sum(:price).to_d
      additional_payment_total = requests.sum(:additional_payment).to_d

      Result.new(
        fiscal_period: @fiscal_period,
        attendance_reserve_total:,
        purchased_book_total:,
        additional_payment_total:,
        balance: attendance_reserve_total - purchased_book_total + additional_payment_total,
        attendance_count: attendances.size,
        purchase_count: requests.count
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
        fiscal_period: nil,
        attendance_reserve_total: 0.to_d,
        purchased_book_total: 0.to_d,
        additional_payment_total: 0.to_d,
        balance: 0.to_d,
        attendance_count: 0,
        purchase_count: 0
      )
    end
  end
end
