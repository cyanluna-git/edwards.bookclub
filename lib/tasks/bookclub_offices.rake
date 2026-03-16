require "json"

namespace :bookclub do
  desc "Backfill office assignments from current member roles"
  task backfill_offices: :environment do
    effective_from = ENV["EFFECTIVE_FROM"]&.then { Date.parse(_1) }
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    plan_path = ENV["PLAN_PATH"].presence || Backfills::MemberOfficeAssignmentPlan::DEFAULT_PATH
    replace_existing = ENV.fetch("REPLACE_EXISTING", "false") == "true"

    result = Backfills::MemberOfficeAssignmentsBackfill.new(
      effective_from:,
      dry_run:,
      plan_path:,
      replace_existing:
    ).call

    puts JSON.pretty_generate(
      created: result.created,
      skipped_member_ids: result.skipped,
      warnings: result.warnings,
      dry_run:,
      replace_existing:,
      plan_path: plan_path.to_s
    )
  end
end
