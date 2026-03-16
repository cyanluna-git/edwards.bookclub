namespace :bookclub do
  desc "Generate a PBIX-to-Rails reconciliation report"
  task reconcile: :environment do
    report = Reconciliation::PbixBaselineReporter.new(
      baseline_path: ENV["BASELINE_JSON"].presence || Reconciliation::PbixBaselineReporter::DEFAULT_BASELINE_PATH,
      report_path: ENV["REPORT_PATH"].presence || Reconciliation::PbixBaselineReporter::DEFAULT_REPORT_PATH
    ).call

    puts "Reconciliation report written to #{report[:report_path]}"
    puts "Development readiness: #{report[:development_ready] ? 'yes' : 'no'}"
    puts "Cutover readiness: #{report[:cutover_ready] ? 'yes' : 'no'}"
    puts "Blockers: #{report[:blockers].presence&.join(', ') || 'none'}"
  end
end
