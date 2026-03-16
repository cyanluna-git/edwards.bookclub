module Admin
  class DashboardSnapshot
    TrendPoint = Struct.new(:label, :count, keyword_init: true)
    LocationPoint = Struct.new(:label, :count, :ratio, keyword_init: true)
    RecentMeeting = Struct.new(:meeting, :attendance_count, :photo_count, keyword_init: true)
    Result = Struct.new(
      :fiscal_period,
      :month_label,
      :month_range,
      :reserve_snapshot,
      :monthly_attendance,
      :location_breakdown,
      :recent_meetings,
      keyword_init: true
    )

    def initialize(fiscal_period: nil, month: nil)
      @fiscal_period = fiscal_period || FiscalPeriod.find_by(active: true)
      @month = month
    end

    def call
      Result.new(
        fiscal_period: @fiscal_period,
        month_label: selected_month_label,
        month_range: selected_month_range,
        reserve_snapshot: Admin::ReserveSnapshot.new(fiscal_period: @fiscal_period).call,
        monthly_attendance: monthly_attendance_points,
        location_breakdown: location_points,
        recent_meetings: recent_meeting_points
      )
    end

    private

    def selected_month_label
      return "All months" unless selected_month_range

      selected_month_range.begin.strftime("%B %Y")
    end

    def selected_month_range
      return @selected_month_range if defined?(@selected_month_range)
      return @selected_month_range = nil if @month.blank?

      @selected_month_range =
        begin
          date = Date.strptime(@month, "%Y-%m")
          date.beginning_of_month..date.end_of_month
        rescue ArgumentError
          nil
        end
    end

    def meetings_scope
      scope = Meeting.includes(:meeting_photos, :meeting_attendances).ordered_recent
      scope = scope.where(fiscal_period_id: @fiscal_period.id) if @fiscal_period
      scope = scope.where(meeting_at: selected_month_range) if selected_month_range
      scope
    end

    def attendance_scope
      scope = MeetingAttendance.joins(:meeting)
      scope = scope.where(meetings: { fiscal_period_id: @fiscal_period.id }) if @fiscal_period
      scope = scope.where(meetings: { meeting_at: selected_month_range }) if selected_month_range
      scope
    end

    def monthly_attendance_points
      if @fiscal_period
        months = (@fiscal_period.start_date.beginning_of_month..@fiscal_period.end_date.beginning_of_month).select { |date| date.day == 1 }
      else
        latest = Meeting.order(meeting_at: :desc).limit(6).pluck(:meeting_at).compact.map(&:to_date).map(&:beginning_of_month).uniq.sort
        months = latest
      end

      counts = MeetingAttendance.joins(:meeting)
        .yield_self { |scope| @fiscal_period ? scope.where(meetings: { fiscal_period_id: @fiscal_period.id }) : scope }
        .group("strftime('%Y-%m', meetings.meeting_at)")
        .count

      months.map do |month_date|
        TrendPoint.new(
          label: month_date.strftime("%Y-%m"),
          count: counts.fetch(month_date.strftime("%Y-%m"), 0)
        )
      end
    end

    def location_points
      counts = attendance_scope.group("COALESCE(meetings.location, 'No location')").count
      total = counts.values.sum

      counts.sort_by { |label, count| [-count, label] }.map do |label, count|
        LocationPoint.new(label:, count:, ratio: total.zero? ? 0 : count.to_f / total)
      end
    end

    def recent_meeting_points
      meetings_scope.limit(5).map do |meeting|
        RecentMeeting.new(
          meeting:,
          attendance_count: meeting.meeting_attendances.size,
          photo_count: meeting.meeting_photos.size
        )
      end
    end
  end
end
