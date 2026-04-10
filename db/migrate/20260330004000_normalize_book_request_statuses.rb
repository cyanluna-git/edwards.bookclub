class NormalizeBookRequestStatuses < ActiveRecord::Migration[8.1]
  class MigrationBookRequest < ApplicationRecord
    self.table_name = "book_requests"
  end

  STATUS_ALIASES = {
    "Requested" => "구매요청",
    "Approved" => "승인완료",
    "Purchased" => "구매완료",
    "Rejected" => "반려",
    "On Hold" => "보류",
    "수령완료" => "구매완료",
    "구매완료확정" => "구매완료"
  }.freeze

  def up
    STATUS_ALIASES.each do |legacy_status, canonical_status|
      MigrationBookRequest.where(request_status: legacy_status).update_all(request_status: canonical_status)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Book request status normalization cannot be reversed safely."
  end
end
