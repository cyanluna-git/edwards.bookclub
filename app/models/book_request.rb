class BookRequest < ApplicationRecord
  belongs_to :member, optional: true
  belongs_to :fiscal_period, optional: true

  validates :title, presence: true
  validates :source_key, uniqueness: { scope: :source_system }, allow_nil: true
  validates :price, :additional_payment, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
