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

  def site_leader_manager?(date = Date.current)
    member&.member_office_assignments&.effective_on(date)&.where(office_type: "site_leader")&.exists? || false
  end

  def can_manage_club?(date = Date.current)
    admin? || chairperson_manager?(date)
  end

  def can_manage_members?(date = Date.current)
    can_manage_club?(date) || site_leader_manager?(date)
  end

  def management_access_label(date = Date.current)
    return "Admin" if admin?
    return "Chairperson" if chairperson_manager?(date)
    return "Site leader" if site_leader_manager?(date)

    "Member"
  end

  def update_microsoft_tokens!(credentials)
    update!(
      microsoft_access_token: credentials["token"],
      microsoft_refresh_token: credentials["refresh_token"],
      microsoft_token_expires_at: credentials["expires_at"] ? Time.at(credentials["expires_at"]) : nil
    )
  end

  def microsoft_token_valid?
    microsoft_access_token.present? &&
      microsoft_token_expires_at.present? &&
      microsoft_token_expires_at > 5.minutes.from_now
  end

  def refresh_microsoft_token!
    raise "No refresh token available. Please sign in with Microsoft SSO again." unless microsoft_refresh_token.present?

    client = OAuth2::Client.new(
      ENV.fetch("ENTRA_CLIENT_ID"),
      ENV.fetch("ENTRA_CLIENT_SECRET"),
      site: "https://login.microsoftonline.com",
      token_url: "/#{ENV.fetch('ENTRA_TENANT_ID')}/oauth2/v2.0/token"
    )
    token = OAuth2::AccessToken.from_hash(client,
      "access_token" => microsoft_access_token,
      "refresh_token" => microsoft_refresh_token
    )
    new_token = token.refresh!
    update!(
      microsoft_access_token: new_token.token,
      microsoft_refresh_token: new_token.refresh_token || microsoft_refresh_token,
      microsoft_token_expires_at: new_token.expires_at ? Time.at(new_token.expires_at) : nil
    )
  end

  def ensure_valid_microsoft_token!
    refresh_microsoft_token! unless microsoft_token_valid?
    microsoft_access_token
  end
end
