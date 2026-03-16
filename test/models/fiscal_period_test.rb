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

  test "allows only one active period" do
    FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    period = FiscalPeriod.new(name: "FY2027", start_date: Date.new(2027, 1, 1), end_date: Date.new(2027, 12, 31), active: true)

    assert_not period.valid?
    assert_includes period.errors[:active], "allows only one active fiscal period at a time"
  end
end
