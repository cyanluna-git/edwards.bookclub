require "test_helper"

module Backfills
  class MemberOfficeAssignmentsBackfillTest < ActiveSupport::TestCase
    setup do
      @plan_path = Rails.root.join("tmp/test_office_tenures.yml")
      FileUtils.rm_f(@plan_path)
    end

    teardown do
      FileUtils.rm_f(@plan_path)
    end

    test "maps current member roles into office assignment attributes" do
      Member.create!(english_name: "Gerald Park", member_role: "Lead", location: "아산", active: true)
      Member.create!(english_name: "Hannah Lee", member_role: "Lead:총무", location: "천안", active: true)
      Member.create!(english_name: "Blake Jung", member_role: "회장", location: "천안", active: true)
      Member.create!(english_name: "Allen Lee", member_role: "정회원", location: "천안", active: true)

      result = MemberOfficeAssignmentsBackfill.new(
        effective_from: Date.new(2026, 1, 1),
        dry_run: true
      ).call

      assert_equal 4, result.created.size
      assert_equal 1, result.skipped.size
      assert result.created.any? { |entry| entry[:member_id] == Member.find_by!(english_name: "Gerald Park").id && entry[:office_type] == "site_leader" && entry[:location] == "아산" }
      assert result.created.any? { |entry| entry[:member_id] == Member.find_by!(english_name: "Hannah Lee").id && entry[:office_type] == "secretary" && entry[:location].nil? }
      assert result.created.any? { |entry| entry[:member_id] == Member.find_by!(english_name: "Hannah Lee").id && entry[:office_type] == "site_leader" && entry[:location] == "천안" }
      assert result.created.any? { |entry| entry[:member_id] == Member.find_by!(english_name: "Blake Jung").id && entry[:office_type] == "chairperson" && entry[:location].nil? }
    end

    test "warns when a leader role has no location for site scope" do
      Member.create!(english_name: "Gerald Park", member_role: "Lead", active: true)

      result = MemberOfficeAssignmentsBackfill.new(
        effective_from: Date.new(2026, 1, 1),
        dry_run: true
      ).call

      assert_equal 0, result.created.size
      assert_equal 1, result.warnings.size
      assert_match "has a leader role but no location", result.warnings.first
    end

    test "uses explicit office tenure plan entries before legacy role fallback" do
      member = Member.create!(english_name: "Gerald Park", email: "gerald@example.com", member_role: "정회원", location: "아산", active: true)
      other = Member.create!(english_name: "Hannah Lee", member_role: "Lead", location: "천안", active: true)

      @plan_path.dirname.mkpath
      @plan_path.write <<~YAML
        members:
          - match:
              email: gerald@example.com
            assignments:
              - office_type: site_leader
                location: 아산
                effective_from: 2026-02-01
                effective_to: 2026-03-31
              - office_type: secretary
                effective_from: 2026-04-01
      YAML

      result = MemberOfficeAssignmentsBackfill.new(
        effective_from: Date.new(2026, 1, 1),
        dry_run: true,
        plan_path: @plan_path
      ).call

      gerald_rows = result.created.select { |entry| entry[:member_id] == member.id }
      hannah_rows = result.created.select { |entry| entry[:member_id] == other.id }

      assert_equal 2, gerald_rows.size
      assert_equal Date.new(2026, 2, 1), gerald_rows.first[:effective_from]
      assert_equal 1, hannah_rows.size
      assert_equal "site_leader", hannah_rows.first[:office_type]
    end
  end
end
