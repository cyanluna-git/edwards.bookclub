class MeetingPhoto < ApplicationRecord
  belongs_to :meeting

  validates :sort_order, numericality: { only_integer: true }
end
