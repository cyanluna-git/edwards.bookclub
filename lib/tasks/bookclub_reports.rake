namespace :bookclub do
  desc "Generate a monthly DOCX report for a fiscal period and month (e.g. 2026-03)"
  task :monthly_docx, [ :period_id, :month ] => :environment do |_task, args|
    abort("Usage: rake bookclub:monthly_docx[period_id,month]") if args[:period_id].blank? || args[:month].blank?

    fiscal_period = FiscalPeriod.find(args[:period_id])
    output_path = Reports::MonthlyDocxGenerator.new(fiscal_period:, month: args[:month]).call

    puts "DOCX report written to #{output_path}"
  end
end
