require "test_helper"

class ReservePolicyTest < ActiveSupport::TestCase
  test "requires effective to on or after effective from" do
    policy = ReservePolicy.new(
      member_role: "정회원",
      attendance_points: 5000,
      effective_from: Date.new(2026, 1, 1),
      effective_to: Date.new(2025, 12, 31)
    )

    assert_not policy.valid?
    assert_includes policy.errors[:effective_to], "must be on or after the effective from date"
  end

  test "rejects overlapping policy windows for the same role" do
    ReservePolicy.create!(
      member_role: "정회원",
      attendance_points: 5000,
      effective_from: Date.new(2026, 1, 1),
      effective_to: Date.new(2026, 12, 31)
    )

    policy = ReservePolicy.new(
      member_role: "정회원",
      attendance_points: 6000,
      effective_from: Date.new(2026, 6, 1),
      effective_to: Date.new(2027, 5, 31)
    )

    assert_not policy.valid?
    assert_includes policy.errors[:base], "effective dates overlap an existing policy for this role"
  end
end
