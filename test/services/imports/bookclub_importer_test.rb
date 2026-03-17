require "test_helper"

class BookclubImporterTest < ActiveSupport::TestCase
  setup do
    [ MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod ].each(&:delete_all)
    FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
  end

  test "imports CSV sources and is idempotent on rerun" do
    importer = Imports::BookclubImporter.new(
      members_csv: fixture_path("imports/members.csv"),
      book_requests_csv: fixture_path("imports/book_requests.csv"),
      attendance_csv: fixture_path("imports/attendance.csv")
    )

    first_result = importer.call

    assert first_result.success?
    assert_equal 2, Member.count
    assert_equal 2, BookRequest.count
    assert_equal 1, Meeting.count
    assert_equal 2, MeetingAttendance.count
    assert_equal 1, MeetingPhoto.count
    assert_equal 2, first_result.skipped.count
    assert_equal 1, first_result.warnings.count

    second_result = importer.call

    assert second_result.success?
    assert_equal 2, Member.count
    assert_equal 2, BookRequest.count
    assert_equal 1, Meeting.count
    assert_equal 2, MeetingAttendance.count
    assert_equal 1, MeetingPhoto.count
    assert second_result.counts["member_updated"] >= 2
    assert second_result.counts["book_request_updated"] >= 2
    assert second_result.counts["meeting_updated"] >= 1
  end

  private

  def fixture_path(relative_path)
    Rails.root.join("test/fixtures", relative_path).to_s
  end
end
