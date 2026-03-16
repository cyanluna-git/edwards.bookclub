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
end
