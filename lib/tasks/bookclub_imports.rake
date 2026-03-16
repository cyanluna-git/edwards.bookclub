require "json"

namespace :bookclub do
  desc "Import members, book requests, and attendance CSV exports into the Rails domain model"
  task import: :environment do
    result = Imports::BookclubImporter.new(
      members_csv: ENV["MEMBERS_CSV"],
      book_requests_csv: ENV["BOOK_REQUESTS_CSV"],
      attendance_csv: ENV["ATTENDANCE_CSV"]
    ).call

    puts JSON.pretty_generate(result.to_h)
    abort("Import failed") unless result.success?
  end
end
