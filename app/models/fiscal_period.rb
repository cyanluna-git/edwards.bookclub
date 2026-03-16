class FiscalPeriod < ApplicationRecord
  has_many :meetings, dependent: :nullify
  has_many :book_requests, dependent: :nullify

  validates :name, :start_date, :end_date, presence: true
  validates :active, inclusion: { in: [true, false] }
  validate :end_date_on_or_after_start_date

  scope :active_first, -> { order(active: :desc, start_date: :asc) }

  private

  def end_date_on_or_after_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
