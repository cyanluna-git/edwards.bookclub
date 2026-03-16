module Admin
  class DashboardSnapshot
    LOCATION_TONES = {
      "동탄" => "dongtan",
      "분당" => "bundang",
      "아산" => "asan",
      "천안" => "cheonan"
    }.freeze

    MonthlyAttendancePoint = Struct.new(:label, :count, :location_counts, keyword_init: true)
    LocationPoint = Struct.new(:label, :count, :ratio, :tone, keyword_init: true)
    AttendanceLeader = Struct.new(:member, :attendance_count, :tone, keyword_init: true)
    ReserveRow = Struct.new(
      :member,
      :attendance_count,
      :attendance_reserve,
      :book_total,
      :additional_payment_total,
      :balance,
      :tone,
      keyword_init: true
    )
    MeetingDigest = Struct.new(
      :meeting,
      :attendees,
      :photos,
      :attendance_count,
      :tone,
      keyword_init: true
    )
    Result = Struct.new(
      :fiscal_period,
      :month_label,
      :selected_month_value,
      :month_range,
      :reserve_snapshot,
      :attendance_leaderboard,
      :reserve_leaderboard,
      :monthly_attendance,
      :location_breakdown,
      :location_legend,
      :meeting_digests,
      :review_highlights,
      keyword_init: true
    )

    def initialize(fiscal_period: nil, month: nil)
      @fiscal_period = fiscal_period || FiscalPeriod.find_by(active: true)
      @month = month
    end

    def call
      meeting_digests = meeting_digests_for_selected_month
      monthly_attendance = monthly_attendance_points
      location_breakdown = location_points

      Result.new(
        fiscal_period: @fiscal_period,
        month_label: selected_month_label,
        selected_month_value: selected_month_value,
        month_range: selected_month_range,
        reserve_snapshot: Admin::ReserveSnapshot.new(fiscal_period: @fiscal_period).call,
        attendance_leaderboard: attendance_leaderboard,
        reserve_leaderboard: reserve_leaderboard,
        monthly_attendance:,
        location_breakdown:,
        location_legend: ordered_locations(monthly_attendance.flat_map { |point| point.location_counts.keys }),
        meeting_digests: meeting_digests,
        review_highlights: meeting_digests.select { |digest| digest.meeting.review.present? }
      )
    end

    private

    def selected_month_value
      selected_month_range&.begin&.strftime("%Y-%m")
    end

    def selected_month_label
      return "No month selected" unless selected_month_range

      selected_month_range.begin.strftime("%Y-%m")
    end

    def selected_month_range
      return @selected_month_range if defined?(@selected_month_range)

      @selected_month_range = month_range_for(@month) || latest_meeting_month_range
    end

    def latest_meeting_month_range
      latest_meeting_at = period_meetings_scope.maximum(:meeting_at)
      return if latest_meeting_at.blank?

      month_range_for(latest_meeting_at.to_date.strftime("%Y-%m"))
    end

    def month_range_for(value)
      return if value.blank?

      date = Date.strptime(value, "%Y-%m")
      date.beginning_of_month..date.end_of_month
    rescue ArgumentError
      nil
    end

    def period_meetings_scope
      scope = Meeting
        .includes(:meeting_photos, meeting_attendances: :member)
        .ordered_recent
      scope = scope.where(fiscal_period_id: @fiscal_period.id) if @fiscal_period
      scope
    end

    def selected_month_meetings_scope
      scope = period_meetings_scope
      scope = scope.where(meeting_at: selected_month_range) if selected_month_range
      scope
    end

    def period_attendance_scope
      scope = MeetingAttendance
        .includes(:member, :meeting)
        .joins(:meeting)
      scope = scope.where(meetings: { fiscal_period_id: @fiscal_period.id }) if @fiscal_period
      scope
    end

    def selected_month_attendance_scope
      scope = period_attendance_scope
      scope = scope.where(meetings: { meeting_at: selected_month_range }) if selected_month_range
      scope
    end

    def attendance_leaderboard
      counts = period_attendance_scope.group(:member_id).count
      members = Member.where(id: counts.keys).index_by(&:id)

      counts.sort_by { |member_id, count| [-count, members[member_id]&.display_name.to_s] }.first(10).filter_map do |member_id, count|
        member = members[member_id]
        next if member.nil?

        AttendanceLeader.new(
          member:,
          attendance_count: count,
          tone: location_tone(member.location)
        )
      end
    end

    def reserve_leaderboard
      Member
        .includes(:book_requests, meeting_attendances: :meeting)
        .ordered
        .filter_map do |member|
          attendance_rows = member.meeting_attendances.select do |attendance|
            attendance_in_fiscal_period?(attendance) && !attendance.reserve_exempt?
          end
          request_rows = member.book_requests.select { |request| request_in_fiscal_period?(request) }

          attendance_reserve = attendance_rows.sum { |attendance| attendance.effective_awarded_points.to_d }
          book_total = request_rows.sum { |request| request.price.to_d }
          additional_payment_total = request_rows.sum { |request| request.additional_payment.to_d }
          balance = attendance_reserve - book_total + additional_payment_total

          next if attendance_reserve.zero? && book_total.zero? && additional_payment_total.zero?

          ReserveRow.new(
            member:,
            attendance_count: attendance_rows.size,
            attendance_reserve:,
            book_total:,
            additional_payment_total:,
            balance:,
            tone: location_tone(member.location)
          )
        end
        .sort_by { |row| [-row.balance.to_d, row.member.display_name.to_s] }
      end

    def monthly_attendance_points
      counts = period_attendance_scope.group("strftime('%Y-%m', meetings.meeting_at)", "COALESCE(meetings.location, '미정')").count

      timeline_months.map do |month_date|
        label = month_date.strftime("%Y-%m")
        location_counts = counts.each_with_object({}) do |((month_label, location_label), count), memo|
          memo[location_label] = count if month_label == label
        end

        MonthlyAttendancePoint.new(
          label:,
          count: location_counts.values.sum,
          location_counts:
        )
      end
    end

    def location_points
      counts = selected_month_attendance_scope.group("COALESCE(meetings.location, '미정')").count
      total = counts.values.sum

      ordered_locations(counts.keys).filter_map do |location_label|
        count = counts[location_label]
        next if count.blank?

        LocationPoint.new(
          label: location_label,
          count:,
          ratio: total.zero? ? 0 : count.to_f / total,
          tone: location_tone(location_label)
        )
      end
    end

    def meeting_digests_for_selected_month
      selected_month_meetings_scope.map do |meeting|
        MeetingDigest.new(
          meeting:,
          attendees: meeting.meeting_attendances.sort_by { |attendance| [attendance.member.display_name.to_s, attendance.id.to_i] }.map(&:member),
          photos: meeting.meeting_photos.sort_by { |photo| [photo.sort_order || 0, photo.id] },
          attendance_count: meeting.meeting_attendances.size,
          tone: location_tone(meeting.location)
        )
      end
    end

    def ordered_locations(labels)
      canonical = LOCATION_TONES.keys
      extras = labels.compact.uniq - canonical
      canonical.select { |label| labels.include?(label) } + extras.sort
    end

    def location_tone(label)
      LOCATION_TONES.fetch(label.to_s, "neutral")
    end

    def attendance_in_fiscal_period?(attendance)
      return true unless @fiscal_period

      attendance.meeting&.fiscal_period_id == @fiscal_period.id
    end

    def request_in_fiscal_period?(request)
      return true unless @fiscal_period

      request.fiscal_period_id == @fiscal_period.id
    end
    def timeline_months
      if @fiscal_period
        month = @fiscal_period.start_date.beginning_of_month
        months = []

        while month <= @fiscal_period.end_date.beginning_of_month
          months << month
          month = month.next_month
        end

        return months
      end

      latest_months = Meeting
        .order(meeting_at: :desc)
        .limit(6)
        .pluck(:meeting_at)
        .compact
        .map(&:to_date)
        .map(&:beginning_of_month)
        .uniq
        .sort

      latest_months.presence || [Date.current.beginning_of_month]
    end
  end
end
