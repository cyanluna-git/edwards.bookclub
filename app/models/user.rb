class User < ApplicationRecord
  ROLES = %w[admin member].freeze

  belongs_to :member, optional: true
  has_many :created_meetings, class_name: "Meeting", foreign_key: :created_by_id, dependent: :nullify, inverse_of: :created_by

  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, :role, presence: true
  validates :email, uniqueness: true
  validates :role, inclusion: { in: ROLES }

  def self.find_or_provision_from_sso(email)
    normalized_email = email.to_s.strip.downcase
    return if normalized_email.blank?

    user = find_by(email: normalized_email)
    member = Member.find_by(email: normalized_email)

    if user.present?
      if member.present? && user.member.nil?
        user.update!(member:)
      end

      return user
    end

    return unless member&.active?
    return if member.user.present?

    generated_password = SecureRandom.base58(24)

    create!(
      email: normalized_email,
      member:,
      role: "member",
      password: generated_password,
      password_confirmation: generated_password
    )
  end

  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end

  def chairperson_manager?(date = Date.current)
    member&.member_office_assignments&.effective_on(date)&.where(office_type: "chairperson")&.exists? || false
  end

  def can_manage_club?(date = Date.current)
    admin? || chairperson_manager?(date)
  end

  def management_access_label(date = Date.current)
    return "Admin" if admin?
    return "Chairperson" if chairperson_manager?(date)

    "Member"
  end
end
