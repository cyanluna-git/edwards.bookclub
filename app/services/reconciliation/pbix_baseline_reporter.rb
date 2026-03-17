require "json"
require "fileutils"

module Reconciliation
  class PbixBaselineReporter
    DEFAULT_BASELINE_PATH = Rails.root.join("artifacts/current_state.json").freeze
    DEFAULT_REPORT_PATH = Rails.root.join("reports/reconciliation/pbix_baseline_report.md").freeze

    def initialize(baseline_path: DEFAULT_BASELINE_PATH, report_path: DEFAULT_REPORT_PATH)
      @baseline_path = Pathname(baseline_path)
      @report_path = Pathname(report_path)
    end

    def call
      baseline = JSON.parse(@baseline_path.read)
      report = build_report(baseline)

      FileUtils.mkdir_p(@report_path.dirname)
      @report_path.write(render_markdown(report))

      report.merge(report_path: @report_path.to_s)
    end

    private

    def build_report(baseline)
      comparisons = []
      comparisons << count_comparison("Members", baseline_count(baseline, "Members"), Member.count, "Full PBIX-derived members export is available locally.")
      comparisons << count_comparison("Book Requests", baseline_count(baseline, "도서신청"), BookRequest.count, "Rails currently reflects imported CSV scope; full SharePoint export has not been loaded yet.")
      comparisons << count_comparison("Attendance Rows", baseline_count(baseline, "출석!"), MeetingAttendance.count, "Rails currently reflects imported CSV scope; full SharePoint export has not been loaded yet.")
      comparisons << simple_comparison("Member Reserve Points", baseline_measure(baseline, "MembersPoint"), reserve_policy_points("정회원"), "Checks parity for the general member attendance rule.")
      comparisons << simple_comparison("Leader Reserve Points", baseline_measure(baseline, "LeadersPoint"), leader_points_value, "Checks parity for leader attendance rules.")
      comparisons << simple_comparison("Fiscal Period Start", baseline_fiscal_start(baseline), active_fiscal_period_start, "Derived from the PBIX `SumOfBooks` date boundary and current seeded fiscal period.")

      blockers = comparisons.select { |comparison| comparison[:status] == "mismatch" }.map { |comparison| comparison[:label] }
      development_ready = comparisons.any? { |comparison| comparison[:label] == "Members" && comparison[:status] == "match" }
      cutover_ready = blockers.empty?

      {
        generated_at: Time.current.iso8601,
        baseline_path: @baseline_path.to_s,
        comparisons:,
        blockers:,
        development_ready:,
        cutover_ready:
      }
    end

    def count_comparison(label, baseline, actual, note)
      status =
        if baseline.nil?
          "not_comparable"
        elsif baseline == actual
          "match"
        else
          "mismatch"
        end

      {
        label:,
        baseline: baseline || "n/a",
        actual:,
        status:,
        note:
      }
    end

    def simple_comparison(label, baseline, actual, note)
      status =
        if baseline.blank? || actual.blank?
          "not_comparable"
        elsif baseline.to_s == actual.to_s
          "match"
        else
          "mismatch"
        end

      {
        label:,
        baseline: baseline || "n/a",
        actual: actual || "n/a",
        status:,
        note:
      }
    end

    def baseline_count(baseline, table_name)
      row = baseline.fetch("statistics", []).find do |stat|
        stat["TableName"] == table_name && stat["ColumnName"] == "ID"
      end
      row&.fetch("Cardinality", nil)
    end

    def baseline_measure(baseline, measure_name)
      row = baseline.fetch("measures", []).find { |measure| measure["Name"] == measure_name }
      row&.fetch("Expression", nil)&.to_s&.strip
    end

    def baseline_fiscal_start(baseline)
      row = baseline.fetch("measures", []).find { |measure| measure["Name"] == "SumOfBooks" }
      expression = row&.fetch("Expression", nil).to_s
      match = expression.match(/DATE\((\d+),\s*(\d+),\s*(\d+)\)/)
      return unless match

      Date.new(match[1].to_i, match[2].to_i, match[3].to_i).iso8601
    end

    def reserve_policy_points(role_name)
      ReservePolicy.find_by(member_role: role_name)&.attendance_points&.to_s
    end

    def leader_points_value
      points = ReservePolicy.where(member_role: [ "Lead", "Lead:총무" ]).distinct.pluck(:attendance_points)
      return if points.empty? || points.uniq.many?

      points.first.to_s
    end

    def active_fiscal_period_start
      FiscalPeriod.find_by(active: true)&.start_date&.iso8601
    end

    def render_markdown(report)
      lines = []
      lines << "# PBIX Baseline Reconciliation Report"
      lines << ""
      lines << "- Generated: #{report[:generated_at]}"
      lines << "- Baseline: `#{report[:baseline_path]}`"
      lines << ""
      lines << "## Summary"
      lines << ""
      lines << "- Development readiness: #{report[:development_ready] ? 'yes' : 'no'}"
      lines << "- Cutover readiness: #{report[:cutover_ready] ? 'yes' : 'no'}"
      lines << "- Blockers: #{report[:blockers].presence&.join(', ') || 'none'}"
      lines << ""
      lines << "## Comparisons"
      lines << ""
      lines << "| Item | PBIX Baseline | Rails Current | Status | Notes |"
      lines << "|------|---------------|---------------|--------|-------|"
      report[:comparisons].each do |comparison|
        lines << "| #{comparison[:label]} | #{comparison[:baseline]} | #{comparison[:actual]} | #{comparison[:status]} | #{comparison[:note]} |"
      end
      lines << ""
      lines << "## Assessment"
      lines << ""
      if report[:development_ready]
        lines << "- The current migration baseline is sufficient to continue Rails feature development."
      else
        lines << "- The current migration baseline is not yet sufficient even for continued feature development."
      end
      if report[:cutover_ready]
        lines << "- The imported data is sufficiently aligned for cutover review."
      else
        lines << "- The imported data is not yet ready for cutover because one or more blocker mismatches remain."
      end
      lines << "- Current mismatches are expected where the repo uses fixture SharePoint CSVs instead of the full live exports."
      lines << ""
      lines.join("\n") + "\n"
    end
  end
end
