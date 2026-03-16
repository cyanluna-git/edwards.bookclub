module Imports
  class MembersImporter < BaseImporter
    SOURCE_SYSTEM = "sharepoint_members".freeze

    def call
      each_row do |row|
        source_key = normalize_text(row["ID"])
        if source_key.blank?
          result.skipped!(:member, row_identifier: row.inspect, reason: "missing member ID")
          next
        end

        member = Member.find_or_initialize_by(source_system: SOURCE_SYSTEM, source_key:)
        new_record = member.new_record?

        member.assign_attributes(
          english_name: normalize_text(row["Title"]) || "Unknown Member #{source_key}",
          korean_name: normalize_text(row["한글이름"]),
          department: normalize_text(row["부서"]),
          email: normalize_text(row["email"]),
          member_role: normalize_text(row["Role"]) || "정회원",
          location: normalize_text(row["Location"]),
          active: true
        )

        if member.save
          new_record ? result.imported(:member) : result.updated(:member)
        else
          result.error!(:member, row_identifier: source_key, reason: member.errors.full_messages.to_sentence)
        end
      end

      result
    end
  end
end
