class Member < ApplicationRecord
  has_one :user, dependent: :nullify
  has_many :meeting_attendances, dependent: :delete_all
  has_many :meetings, through: :meeting_attendances
  has_many :book_requests, dependent: :nullify

  validates :english_name, :member_role, presence: true
  validates :email, uniqueness: true, allow_blank: true
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validates :active, inclusion: { in: [true, false] }

  def leader_role?
    member_role.to_s.include?("Lead")
  end

  def display_name
    korean_name.presence || english_name
  end
end
