class MeetingPhoto < ApplicationRecord
  belongs_to :meeting

  validates :sort_order, numericality: { only_integer: true }
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
end
