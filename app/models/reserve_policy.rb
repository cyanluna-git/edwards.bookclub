class ReservePolicy < ApplicationRecord
  validates :member_role, :effective_from, presence: true
  validates :attendance_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :member_role, uniqueness: { scope: :effective_from }
  validate :effective_to_on_or_after_effective_from
  validate :non_overlapping_effective_window

  scope :ordered, -> { order(member_role: :asc, effective_from: :desc, id: :desc) }

  private

  def effective_to_on_or_after_effective_from
    return if effective_from.blank? || effective_to.blank?
    return if effective_to >= effective_from

    errors.add(:effective_to, "must be on or after the effective from date")
  end

  def non_overlapping_effective_window
    return if member_role.blank? || effective_from.blank?

    overlap = self.class.where(member_role:).where.not(id:).any? do |policy|
      start_a = effective_from
      finish_a = effective_to || Date::Infinity.new
      start_b = policy.effective_from
      finish_b = policy.effective_to || Date::Infinity.new

      start_a <= finish_b && start_b <= finish_a
    end

    errors.add(:base, "effective dates overlap an existing policy for this role") if overlap
  end
end
