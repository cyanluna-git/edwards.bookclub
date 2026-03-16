require "json"

namespace :bookclub do
  desc "Backfill reserve award snapshots for existing attendance rows"
  task snapshot_attendance_awards: :environment do
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    refreshed = []

    MeetingAttendance.includes(:meeting, :member).find_each do |attendance|
      next unless attendance.meeting && attendance.member

      result = attendance.refresh_award_snapshot(force: true)

      if dry_run
        refreshed << {
          attendance_id: attendance.id,
          member_id: attendance.member_id,
          meeting_id: attendance.meeting_id,
          awarded_points: result.awarded_points,
          effective_points: result.effective_points,
          policy_role: result.policy_role,
          source: result.source
        }
      else
        attendance.save! if attendance.changed?
      end
    end

    puts JSON.pretty_generate(
      dry_run:,
      refreshed_count: refreshed.size,
      sample: dry_run ? refreshed.first(25) : []
    )
  end
end
