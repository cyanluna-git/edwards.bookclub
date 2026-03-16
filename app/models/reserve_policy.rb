class ReservePolicy < ApplicationRecord
  validates :member_role, :effective_from, presence: true
  validates :attendance_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :member_role, uniqueness: { scope: :effective_from }
  validate :effective_to_on_or_after_effective_from

  private

  def effective_to_on_or_after_effective_from
    return if effective_from.blank? || effective_to.blank?
    return if effective_to >= effective_from

    errors.add(:effective_to, "must be on or after the effective from date")
  end
end
