require "fileutils"

module Reconciliation
  class HistoricalReserveReporter
    DEFAULT_REPORT_PATH = Rails.root.join("reports/reconciliation/historical_reserve_report.md").freeze

    def initialize(report_path: DEFAULT_REPORT_PATH)
      @report_path = Pathname(report_path)
    end

    def call
      report = build_report

      FileUtils.mkdir_p(@report_path.dirname)
      @report_path.write(render_markdown(report))

      report.merge(report_path: @report_path.to_s)
    end

    private

    def build_report
      missing_office_assignments = current_manager_labels_without_assignments
      manual_overrides = manual_override_rows
      same_day_multi_attendance = same_day_multi_attendance_rows
      pending_snapshots = pending_snapshot_rows

      blockers = []
      blockers << "manager labels missing office assignments" if missing_office_assignments.any?
      blockers << "attendance rows pending award snapshots" if pending_snapshots.any?
      blockers << "same-day multi-attendance exceptions" if same_day_multi_attendance.any?

      {
        generated_at: Time.current.iso8601,
        blockers:,
        cutover_ready: blockers.empty?,
        office_assignment_count: MemberOfficeAssignment.count,
        missing_office_assignments:,
        manual_overrides:,
        same_day_multi_attendance:,
        pending_snapshots:
      }
    end

    def current_manager_labels_without_assignments
      Member.ordered.filter_map do |member|
        next unless member.member_role.to_s.match?(/회장|총무|Lead/)
        next if member.member_office_assignments.exists?

        {
          member_id: member.id,
          name: member.display_name,
          role_label: member.member_role,
          location: member.location.presence || "미정"
        }
      end
    end

    def manual_override_rows
      MeetingAttendance
        .includes(:member, :meeting)
        .where.not(override_points: nil)
        .order(updated_at: :desc, id: :desc)
        .map do |attendance|
          {
            attendance_id: attendance.id,
            meeting_title: attendance.meeting&.title,
            meeting_date: attendance.meeting&.meeting_at&.to_date&.iso8601,
            member_name: attendance.member&.display_name,
            override_points: attendance.override_points,
            default_points: attendance.awarded_points,
            effective_points: attendance.effective_awarded_points,
            note: attendance.note.to_s.strip
          }
        end
    end

    def same_day_multi_attendance_rows
      rows = MeetingAttendance
        .joins(:meeting, :member)
        .group(:member_id, Arel.sql("DATE(meetings.meeting_at)"))
        .having("COUNT(*) > 1")
        .count

      rows.map do |(member_id, meeting_date), count|
        member = Member.find_by(id: member_id)
        meetings = MeetingAttendance
          .includes(:meeting)
          .where(member_id:)
          .joins(:meeting)
          .where("DATE(meetings.meeting_at) = ?", meeting_date)
          .order("meetings.meeting_at ASC")

        {
          member_id:,
          member_name: member&.display_name,
          meeting_date: meeting_date.to_s,
          attendance_count: count,
          meetings: meetings.map do |attendance|
            {
              meeting_id: attendance.meeting_id,
              title: attendance.meeting&.title,
              location: attendance.meeting&.location,
              awarded_points: attendance.effective_awarded_points,
              override_points: attendance.override_points
            }
          end
        }
      end
    end

    def pending_snapshot_rows
      MeetingAttendance
        .includes(:member, :meeting)
        .where(awarded_points: nil, reserve_exempt: false, override_points: nil)
        .order(id: :asc)
        .map do |attendance|
          {
            attendance_id: attendance.id,
            meeting_title: attendance.meeting&.title,
            meeting_date: attendance.meeting&.meeting_at&.to_date&.iso8601,
            member_name: attendance.member&.display_name
          }
        end
    end

    def render_markdown(report)
      lines = []
      lines << "# Historical Reserve Reconciliation Report"
      lines << ""
      lines << "- Generated: #{report[:generated_at]}"
      lines << "- Office assignments loaded: #{report[:office_assignment_count]}"
      lines << "- Cutover ready: #{report[:cutover_ready] ? 'yes' : 'no'}"
      lines << "- Blockers: #{report[:blockers].presence&.join(', ') || 'none'}"
      lines << ""
      lines << "## Manager Labels Missing Office Assignments"
      lines << ""
      if report[:missing_office_assignments].any?
        lines << "| Member | Legacy role | Location |"
        lines << "|--------|-------------|----------|"
        report[:missing_office_assignments].each do |row|
          lines << "| #{row[:name]} | #{row[:role_label]} | #{row[:location]} |"
        end
      else
        lines << "None."
      end
      lines << ""
      lines << "## Manual Attendance Overrides"
      lines << ""
      if report[:manual_overrides].any?
        lines << "| Date | Meeting | Member | Default | Override | Effective | Note |"
        lines << "|------|---------|--------|---------|----------|-----------|------|"
        report[:manual_overrides].each do |row|
          lines << "| #{row[:meeting_date]} | #{row[:meeting_title]} | #{row[:member_name]} | #{row[:default_points]} | #{row[:override_points]} | #{row[:effective_points]} | #{row[:note].presence || '-'} |"
        end
      else
        lines << "None."
      end
      lines << ""
      lines << "## Same-Day Multi-Attendance Exceptions"
      lines << ""
      if report[:same_day_multi_attendance].any?
        report[:same_day_multi_attendance].each do |row|
          lines << "- #{row[:meeting_date]} · #{row[:member_name]} · #{row[:attendance_count]} attendance rows"
          row[:meetings].each do |meeting|
            lines << "  - #{meeting[:title]} (#{meeting[:location].presence || '미정'}) · #{meeting[:awarded_points]} points#{meeting[:override_points].present? ? " · override #{meeting[:override_points]}" : ''}"
          end
        end
      else
        lines << "None."
      end
      lines << ""
      lines << "## Pending Award Snapshots"
      lines << ""
      if report[:pending_snapshots].any?
        lines << "| Attendance ID | Date | Meeting | Member |"
        lines << "|---------------|------|---------|--------|"
        report[:pending_snapshots].each do |row|
          lines << "| #{row[:attendance_id]} | #{row[:meeting_date]} | #{row[:meeting_title]} | #{row[:member_name]} |"
        end
      else
        lines << "None."
      end
      lines << ""
      lines << "## Operator Guidance"
      lines << ""
      lines << "- Use office assignments for dated leadership handoffs."
      lines << "- Use `override_points` for one-off reserve corrections."
      lines << "- Do not add fake attendance rows to force reserve totals."
      lines << ""
      lines.join("\n") + "\n"
    end
  end
end
