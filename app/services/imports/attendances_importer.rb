require "digest"

module Imports
  class AttendancesImporter < BaseImporter
    MEETING_SOURCE_SYSTEM = "sharepoint_attendance_meetings".freeze
    ATTENDANCE_SOURCE_SYSTEM = "sharepoint_attendances".freeze
    PHOTO_SOURCE_SYSTEM = "sharepoint_attendance_photos".freeze

    def call
      each_row do |row|
        attendance_source_key = normalize_text(row["ID"])
        meeting_at = parse_datetime(row["모임일시"])

        if attendance_source_key.blank? || meeting_at.blank?
          result.skipped!(:attendance, row_identifier: row.inspect, reason: "missing attendance ID or invalid meeting datetime")
          next
        end

        meeting = upsert_meeting(row, meeting_at)
        next if meeting.nil?

        member = member_from_lookup(
          source_id: normalize_text(row["참석자.lookupId"]),
          display_name: normalize_text(row["참석자.lookupValue"])
        )

        if member.nil?
          result.skipped!(:attendance, row_identifier: attendance_source_key, reason: "member lookup could not be resolved")
          next
        end

        attendance = MeetingAttendance.find_or_initialize_by(
          source_system: ATTENDANCE_SOURCE_SYSTEM,
          source_key: attendance_source_key
        )
        new_record = attendance.new_record?
        attendance.assign_attributes(
          meeting:,
          member:,
          reserve_exempt: parse_boolean(row["No적립금?"]),
          note: normalize_text(row["후기"])
        )

        if attendance.save
          new_record ? result.imported(:attendance) : result.updated(:attendance)
        else
          result.error!(:attendance, row_identifier: attendance_source_key, reason: attendance.errors.full_messages.to_sentence)
          next
        end

        upsert_meeting_photo(row, meeting, attendance_source_key)
      end

      result
    end

    private

    def upsert_meeting(row, meeting_at)
      raw_title = normalize_text(row["Title"])
      location = normalize_text(row["Location"])
      source_key = Digest::SHA256.hexdigest([raw_title, meeting_at.iso8601, location].join("|"))

      meeting = Meeting.find_or_initialize_by(source_system: MEETING_SOURCE_SYSTEM, source_key:)
      new_record = meeting.new_record?
      existing_review = normalize_text(meeting.review)
      incoming_review = normalize_text(row["후기"])

      if existing_review.present? && incoming_review.present? && existing_review != incoming_review
        result.warn!(:meeting, row_identifier: source_key, reason: "conflicting review text encountered; keeping existing review")
      end

      meeting.assign_attributes(
        legacy_title: raw_title,
        title: raw_title || "Meeting on #{meeting_at.to_date}",
        meeting_at:,
        location:,
        review: existing_review || incoming_review,
        fiscal_period: fiscal_period_for(meeting_at)
      )

      if meeting.save
        new_record ? result.imported(:meeting) : result.updated(:meeting)
        meeting
      else
        result.error!(:meeting, row_identifier: source_key, reason: meeting.errors.full_messages.to_sentence)
        nil
      end
    end

    def upsert_meeting_photo(row, meeting, attendance_source_key)
      source_url = normalize_text(row["ImageURL"])
      return if source_url.blank?

      photo = MeetingPhoto.find_or_initialize_by(
        source_system: PHOTO_SOURCE_SYSTEM,
        source_key: "#{attendance_source_key}:image"
      )
      new_record = photo.new_record?
      photo.assign_attributes(meeting:, source_url:)

      if photo.save
        new_record ? result.imported(:meeting_photo) : result.updated(:meeting_photo)
      else
        result.error!(:meeting_photo, row_identifier: attendance_source_key, reason: photo.errors.full_messages.to_sentence)
      end
    end
  end
end
