class Meeting < ApplicationRecord
  belongs_to :fiscal_period, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :meeting_attendances, dependent: :delete_all
  has_many :members, through: :meeting_attendances
  has_many :meeting_photos, dependent: :delete_all

  validates :title, :meeting_at, presence: true
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validates :reserve_exempt_default, inclusion: { in: [true, false] }
end
