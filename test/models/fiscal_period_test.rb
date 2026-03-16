require "test_helper"

class FiscalPeriodTest < ActiveSupport::TestCase
  test "requires end date on or after start date" do
    period = FiscalPeriod.new(
      name: "Bad Period",
      start_date: Date.new(2026, 12, 31),
      end_date: Date.new(2026, 1, 1),
      active: true
    )

    assert_not period.valid?
    assert_includes period.errors[:end_date], "must be on or after the start date"
  end
end
