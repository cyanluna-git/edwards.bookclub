class BookRequest < ApplicationRecord
  SEARCH_COLUMNS = %w[book_requests.title book_requests.author book_requests.publisher book_requests.comment book_requests.request_status].freeze
  CANONICAL_STATUSES = {
    requested: "구매요청",
    approved: "승인완료",
    purchased: "구매완료",
    rejected: "반려",
    on_hold: "보류"
  }.freeze
  STATUS_ALIASES = {
    "Requested" => CANONICAL_STATUSES[:requested],
    "Approved" => CANONICAL_STATUSES[:approved],
    "Purchased" => CANONICAL_STATUSES[:purchased],
    "Rejected" => CANONICAL_STATUSES[:rejected],
    "On Hold" => CANONICAL_STATUSES[:on_hold],
    "구매요청" => CANONICAL_STATUSES[:requested],
    "승인완료" => CANONICAL_STATUSES[:approved],
    "구매완료" => CANONICAL_STATUSES[:purchased],
    "수령완료" => CANONICAL_STATUSES[:purchased],
    "구매완료확정" => CANONICAL_STATUSES[:purchased],
    "반려" => CANONICAL_STATUSES[:rejected],
    "보류" => CANONICAL_STATUSES[:on_hold]
  }.freeze
  DEFAULT_STATUSES = CANONICAL_STATUSES.values.freeze

  belongs_to :member, optional: true
  belongs_to :fiscal_period, optional: true

  normalizes :title, :author, :publisher, :cover_url, :link_url, :comment, :rating, with: ->(value) { value&.strip }
  normalizes :request_status, with: ->(value) { normalize_status_value(value) }

  scope :ordered_recent, -> { order(requested_on: :desc, created_at: :desc, id: :desc) }
  scope :with_member, ->(member_id) { member_id.present? ? where(member_id:) : all }
  scope :with_status, lambda { |status|
    normalized = normalize_status_value(status)
    normalized.present? ? where(request_status: normalized) : all
  }
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
    (DEFAULT_STATUSES + distinct.order(:request_status).pluck(:request_status).map { |status| normalize_status_value(status) }).compact_blank.uniq
  end

  def self.default_status
    CANONICAL_STATUSES[:requested]
  end

  def self.purchased_status
    CANONICAL_STATUSES[:purchased]
  end

  def self.normalize_status_value(value)
    normalized = value.to_s.strip
    return if normalized.blank?

    STATUS_ALIASES.fetch(normalized, normalized)
  end

  def net_cash_effect
    additional_payment.to_d - price.to_d
  end

  def request_status_label
    self.class.normalize_status_value(request_status) || self.class.default_status
  end

  def requested?
    request_status_label == self.class.default_status
  end

  def purchased?
    request_status_label == self.class.purchased_status
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
