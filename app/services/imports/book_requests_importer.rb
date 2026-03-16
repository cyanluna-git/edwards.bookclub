module Imports
  class BookRequestsImporter < BaseImporter
    SOURCE_SYSTEM = "sharepoint_book_requests".freeze

    def call
      each_row do |row|
        source_key = normalize_text(row["ID"])
        title = normalize_text(row["Title"])

        if source_key.blank? || title.blank?
          result.skipped!(:book_request, row_identifier: row.inspect, reason: "missing request ID or title")
          next
        end

        request = BookRequest.find_or_initialize_by(source_system: SOURCE_SYSTEM, source_key:)
        new_record = request.new_record?
        requested_on = parse_date(row["신청일"])

        member = member_from_lookup(
          source_id: normalize_text(row["신청인.lookupId"]),
          display_name: normalize_text(row["신청인.lookupValue"])
        )

        if member.nil? && normalize_text(row["신청인.lookupValue"]).present?
          result.warn!(:book_request, row_identifier: source_key, reason: "member lookup could not be resolved")
        end

        request.assign_attributes(
          member:,
          title:,
          author: normalize_text(row["작가"]),
          publisher: normalize_text(row["출판사"]),
          price: parse_decimal(row["금액"]),
          request_status: normalize_text(row["Progess"]),
          cover_url: normalize_text(row["표지"]),
          link_url: normalize_text(row["링크"]),
          comment: normalize_text(row["신청인한줄평!"]),
          rating: normalize_text(row["별점"]),
          requested_on:,
          additional_payment: parse_additional_payment(row["추가납입금"]),
          fiscal_period: fiscal_period_for(requested_on)
        )

        if request.save
          new_record ? result.imported(:book_request) : result.updated(:book_request)
        else
          result.error!(:book_request, row_identifier: source_key, reason: request.errors.full_messages.to_sentence)
        end
      end

      result
    end

    private

    def parse_additional_payment(value)
      amount = parse_decimal(value)
      return if amount == BigDecimal("-10.0")

      amount
    end
  end
end
