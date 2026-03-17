class BookRequest < ApplicationRecord
  SEARCH_COLUMNS = %w[book_requests.title book_requests.author book_requests.publisher book_requests.comment book_requests.request_status].freeze
  DEFAULT_STATUSES = [ "Requested", "Approved", "Purchased", "Rejected", "On Hold" ].freeze

  belongs_to :member, optional: true
  belongs_to :fiscal_period, optional: true

  normalizes :title, :author, :publisher, :request_status, :cover_url, :link_url, :comment, :rating, with: ->(value) { value&.strip }

  scope :ordered_recent, -> { order(requested_on: :desc, created_at: :desc, id: :desc) }
  scope :with_member, ->(member_id) { member_id.present? ? where(member_id:) : all }
  scope :with_status, ->(status) { status.present? ? where(request_status: status) : all }
  scope :with_fiscal_period, ->(fiscal_period_id) { fiscal_period_id.present? ? where(fiscal_period_id:) : all }
  scope :requested_from, ->(date) { date.present? ? where("requested_on >= ?", date) : all }
  scope :requested_to, ->(date) { date.present? ? where("requested_on <= ?", date) : all }
  scope :search_text, lambda { |query|
    if query.present?
      pattern = "%#{sanitize_sql_like(query.strip)}%"
      left_joins(:member).where(
        (SEARCH_COLUMNS + [ "members.english_name", "members.korean_name" ]).map { |column| "#{column} LIKE :pattern" }.join(" OR "),
        pattern:
      )
    else
      all
    end
  }

  validates :title, presence: true
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validates :price, :additional_payment, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def self.filter(params = {})
    ordered_recent
      .with_member(params[:member_id])
      .with_status(params[:request_status])
      .with_fiscal_period(params[:fiscal_period_id])
      .requested_from(params[:requested_from])
      .requested_to(params[:requested_to])
      .search_text(params[:q])
  end

  def self.status_options
    (DEFAULT_STATUSES + distinct.order(:request_status).pluck(:request_status)).reject(&:blank?).uniq
  end

  def net_cash_effect
    additional_payment.to_d - price.to_d
  end

  def remote_cover_url
    remote_url?(cover_url)
  end

  def remote_link_url
    remote_url?(link_url)
  end

  private

  def remote_url?(value)
    url = value.to_s.strip
    return if url.blank?
    url if url.start_with?("http://", "https://")
  end
end
