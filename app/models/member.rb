class Member < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP
  SEARCH_COLUMNS = %w[english_name korean_name email department location member_role].freeze

  has_one :user, dependent: :nullify
  has_many :meeting_attendances, dependent: :delete_all
  has_many :meetings, through: :meeting_attendances
  has_many :book_requests, dependent: :nullify

  normalizes :english_name, :korean_name, :department, :member_role, :location, with: ->(value) { value&.strip }
  normalizes :email, with: ->(email) { email&.strip&.downcase }

  scope :ordered, -> { order(active: :desc, english_name: :asc, id: :asc) }
  scope :with_active_state, lambda { |active_param|
    case active_param
    when "active" then where(active: true)
    when "inactive" then where(active: false)
    else all
    end
  }
  scope :with_role, ->(role) { role.present? ? where(member_role: role) : all }
  scope :with_location, ->(location) { location.present? ? where(location: location) : all }
  scope :search_text, lambda { |query|
    if query.present?
      pattern = "%#{sanitize_sql_like(query.strip)}%"
      where(
        SEARCH_COLUMNS.map { |column| "members.#{column} LIKE :pattern" }.join(" OR "),
        pattern:
      )
    else
      all
    end
  }

  validates :english_name, :member_role, presence: true
  validates :email, uniqueness: true, allow_blank: true
  validates :email, format: { with: EMAIL_FORMAT }, allow_blank: true
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validates :active, inclusion: { in: [true, false] }

  def self.filter(params = {})
    ordered
      .with_active_state(params[:active])
      .with_role(params[:role])
      .with_location(params[:location])
      .search_text(params[:q])
  end

  def self.role_options
    (ReservePolicy.distinct.order(:member_role).pluck(:member_role) + distinct.order(:member_role).pluck(:member_role)).reject(&:blank?).uniq
  end

  def self.location_options
    distinct.order(:location).pluck(:location).reject(&:blank?)
  end

  def leader_role?
    member_role.to_s.include?("Lead")
  end

  def reserve_policy_role
    return member_role if ReservePolicy.exists?(member_role:)
    return "Lead" if leader_role?

    "정회원"
  end

  def display_name
    korean_name.presence || english_name
  end
end
