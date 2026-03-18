require "json"
require "open3"
require "fileutils"

module Reports
  class MonthlyDocxGenerator
    SCRIPT_PATH = Rails.root.join("script/generate_monthly_report.py").freeze

    class GenerationError < StandardError; end

    def initialize(fiscal_period:, month:)
      @fiscal_period = fiscal_period
      @month = month
    end

    def call
      snapshot = Admin::DashboardSnapshot.new(fiscal_period: @fiscal_period, month: @month).call
      payload = build_payload(snapshot)

      FileUtils.mkdir_p(output_path.dirname)

      stdout, stderr, status = Open3.capture3(
        "python3", SCRIPT_PATH.to_s,
        stdin_data: JSON.generate(payload)
      )

      unless status.success?
        raise GenerationError, "DOCX generation failed (exit #{status.exitstatus}): #{stderr}"
      end

      output_path
    end

    private

    def output_path
      @output_path ||= Rails.root.join("tmp/reports/monthly_#{@month}.docx")
    end

    def build_payload(snapshot)
      {
        activities: build_activities(snapshot.meeting_digests),
        total: snapshot.meeting_digests.sum(&:attendance_count),
        submission_date: Date.current.iso8601,
        output_path: output_path.to_s,
        photos: build_photos(snapshot.meeting_digests)
      }
    end

    def build_activities(digests)
      digests.map do |digest|
        {
          date: digest.meeting.meeting_at.to_date.iso8601,
          description: digest.meeting.title,
          count: digest.attendance_count
        }
      end
    end

    def build_photos(digests)
      digests.flat_map do |digest|
        attendee_names = digest.attendees.map(&:display_name).join(", ")
        location = digest.meeting.location.presence || "미정"

        digest.photos.map do |photo|
          {
            meeting_title: digest.meeting.title,
            meeting_date: digest.meeting.meeting_at.to_date.iso8601,
            location: location,
            attendees: attendee_names,
            source_url: photo.source_url,
            file_path: resolve_photo_path(photo),
            caption: photo.caption
          }
        end
      end
    end

    def resolve_photo_path(photo)
      if photo.image.attached?
        ActiveStorage::Blob.service.path_for(photo.image.key)
      else
        photo.file_path
      end
    end
  end
end
