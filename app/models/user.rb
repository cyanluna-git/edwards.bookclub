class User < ApplicationRecord
  belongs_to :member, optional: true
  has_many :created_meetings, class_name: "Meeting", foreign_key: :created_by_id, dependent: :nullify, inverse_of: :created_by

  validates :email, :role, presence: true
  validates :email, uniqueness: true
end
