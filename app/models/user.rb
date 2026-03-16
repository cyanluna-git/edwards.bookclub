class User < ApplicationRecord
  ROLES = %w[admin member].freeze

  belongs_to :member, optional: true
  has_many :created_meetings, class_name: "Meeting", foreign_key: :created_by_id, dependent: :nullify, inverse_of: :created_by

  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, :role, presence: true
  validates :email, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end
end
