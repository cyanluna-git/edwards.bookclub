require "test_helper"
require "zip"

module Reports
  class MemberRosterXlsxGeneratorTest < ActiveSupport::TestCase
    setup do
      [ MemberOfficeAssignment, User, Member ].each(&:delete_all)

      @active_member = Member.create!(
        english_name: "Gerald Park",
        korean_name: "박제럴드",
        email: "gerald@example.com",
        department: "Vacuum",
        location: "천안",
        member_role: "Lead",
        joined_on: Date.new(2024, 3, 1),
        active: true
      )
      @active_member.member_office_assignments.create!(
        office_type: "chairperson",
        effective_from: Date.current.beginning_of_year
      )

      Member.create!(
        english_name: "Hannah Lee",
        korean_name: "이한나",
        email: "hannah@example.com",
        department: "Finance",
        location: "동탄",
        member_role: "정회원",
        joined_on: Date.new(2025, 7, 10),
        active: false
      )
    end

    test "creates an xlsx roster with member details" do
      path = MemberRosterXlsxGenerator.new(month: "2026-03").call

      assert File.exist?(path)
      assert path.to_s.end_with?("tmp/reports/member_roster_2026-03.xlsx")

      rows = extract_rows(path)
      assert_equal MemberRosterXlsxGenerator::HEADERS, rows.first
      assert_equal "박제럴드", rows.second[0]
      assert_equal "Gerald Park", rows.second[1]
      assert_equal "gerald@example.com", rows.second[3]
      assert_equal "회장", rows.second[7]
      assert_equal "Active", rows.second[8]
      assert_equal "2024-03-01", rows.second[9]
      assert_equal "Inactive", rows.third[8]
    ensure
      FileUtils.rm_f(path) if path
    end

    private

    def extract_rows(path)
      Zip::File.open(path.to_s) do |zip|
        worksheet = Nokogiri::XML(zip.read("xl/worksheets/sheet1.xml"))
        worksheet.remove_namespaces!

        worksheet.xpath("//sheetData/row").map do |row|
          row.xpath("./c").map { |cell| cell.at_xpath(".//t")&.text.to_s }
        end
      end
    end
  end
end
