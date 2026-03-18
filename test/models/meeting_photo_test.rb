require "test_helper"

class MeetingPhotoTest < ActiveSupport::TestCase
  setup do
    period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    @meeting = Meeting.create!(title: "Photo Test Meeting", meeting_at: Time.zone.parse("2026-03-01 19:00:00"), reserve_exempt_default: false, fiscal_period: period)
  end

  test "valid with attached image only" do
    photo = @meeting.meeting_photos.build(sort_order: 1)
    photo.image.attach(
      io: StringIO.new("fake-image-data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    assert photo.valid?, "Photo with attached image should be valid: #{photo.errors.full_messages}"
  end

  test "valid with source_url only" do
    photo = @meeting.meeting_photos.build(source_url: "https://example.com/photo.jpg", sort_order: 1)

    assert photo.valid?, "Photo with source_url should be valid: #{photo.errors.full_messages}"
  end

  test "valid with file_path only" do
    photo = @meeting.meeting_photos.build(file_path: "/uploads/photo.jpg", sort_order: 1)

    assert photo.valid?, "Photo with file_path should be valid: #{photo.errors.full_messages}"
  end

  test "invalid without any asset reference" do
    photo = @meeting.meeting_photos.build(sort_order: 1)

    assert_not photo.valid?
    assert_includes photo.errors[:base], "Photo needs an uploaded image, source URL, or file path"
  end

  test "backward compat: existing source_url photos remain valid" do
    photo = MeetingPhoto.create!(meeting: @meeting, source_url: "https://example.com/old.jpg", sort_order: 0)
    photo.reload

    assert photo.valid?
    assert_not photo.image.attached?
  end

  test "backward compat: existing file_path photos remain valid" do
    photo = MeetingPhoto.create!(meeting: @meeting, file_path: "/old/path.jpg", sort_order: 0)
    photo.reload

    assert photo.valid?
    assert_not photo.image.attached?
  end
end
