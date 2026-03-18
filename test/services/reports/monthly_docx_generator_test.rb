require "test_helper"
require "open3"

module Reports
  class MonthlyDocxGeneratorTest < ActiveSupport::TestCase
    FakeStatus = Struct.new(:exitstatus, keyword_init: true) do
      def success?
        exitstatus == 0
      end
    end

    setup do
      [ MeetingPhoto, MeetingAttendance, Meeting, Member, ReservePolicy, FiscalPeriod ].each(&:delete_all)

      @period = FiscalPeriod.create!(
        name: "FY2026", start_date: Date.new(2026, 1, 1),
        end_date: Date.new(2026, 12, 31), active: true
      )

      @member = Member.create!(english_name: "Gerald Park", member_role: "정회원", location: "아산", active: true)

      @meeting = Meeting.create!(
        title: "March Meetup", meeting_at: Time.zone.parse("2026-03-14 19:00"),
        location: "아산", fiscal_period: @period
      )
      MeetingAttendance.create!(meeting: @meeting, member: @member, reserve_exempt: false)

      @photo = MeetingPhoto.create!(
        meeting: @meeting, source_url: "https://example.com/photo1.jpg",
        caption: "Group photo", sort_order: 0
      )

      @captured_stdin = nil
    end

    test "builds correct json payload" do
      stub_open3(exitstatus: 0) do
        Reports::MonthlyDocxGenerator.new(fiscal_period: @period, month: "2026-03").call
      end

      payload = JSON.parse(@captured_stdin)

      assert_equal 1, payload["activities"].size
      activity = payload["activities"].first
      assert_equal "2026-03-14", activity["date"]
      assert_equal "March Meetup", activity["description"]
      assert_equal 1, activity["count"]

      assert_equal 1, payload["total"]
      assert_equal Date.current.iso8601, payload["submission_date"]
      assert payload["output_path"].end_with?("tmp/reports/monthly_2026-03.docx")

      assert_equal 1, payload["photos"].size
      photo = payload["photos"].first
      assert_equal "March Meetup", photo["meeting_title"]
      assert_equal "2026-03-14", photo["meeting_date"]
      assert_equal "https://example.com/photo1.jpg", photo["source_url"]
      assert_equal "Group photo", photo["caption"]
      assert_nil photo["file_path"]
    end

    test "raises on script failure" do
      error = assert_raises(Reports::MonthlyDocxGenerator::GenerationError) do
        stub_open3(exitstatus: 1, stderr: "something went wrong") do
          Reports::MonthlyDocxGenerator.new(fiscal_period: @period, month: "2026-03").call
        end
      end

      assert_includes error.message, "DOCX generation failed"
      assert_includes error.message, "something went wrong"
    end

    test "handles empty month" do
      stub_open3(exitstatus: 0) do
        Reports::MonthlyDocxGenerator.new(fiscal_period: @period, month: "2026-07").call
      end

      payload = JSON.parse(@captured_stdin)
      assert_equal [], payload["activities"]
      assert_equal 0, payload["total"]
      assert_equal [], payload["photos"]
    end

    test "handles meetings without photos" do
      @photo.destroy!

      stub_open3(exitstatus: 0) do
        Reports::MonthlyDocxGenerator.new(fiscal_period: @period, month: "2026-03").call
      end

      payload = JSON.parse(@captured_stdin)
      assert_equal 1, payload["activities"].size
      assert_equal [], payload["photos"]
    end

    test "creates output directory" do
      output_dir = Rails.root.join("tmp/reports")
      FileUtils.rm_rf(output_dir)

      stub_open3(exitstatus: 0) do
        Reports::MonthlyDocxGenerator.new(fiscal_period: @period, month: "2026-03").call
      end

      assert Dir.exist?(output_dir)
    end

    private

    def stub_open3(exitstatus:, stderr: "")
      test_instance = self
      fake_status = FakeStatus.new(exitstatus:)

      Open3.define_singleton_method(:capture3) do |*_args, **kwargs|
        test_instance.instance_variable_set(:@captured_stdin, kwargs[:stdin_data])
        [ "", stderr, fake_status ]
      end

      yield
    ensure
      Open3.singleton_class.remove_method(:capture3)
    end
  end
end
