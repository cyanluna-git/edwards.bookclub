require "cgi"
require "fileutils"
require "zip"

module Reports
  class MemberRosterXlsxGenerator
    HEADERS = [
      "Name",
      "English name",
      "Korean name",
      "Email",
      "Department",
      "Location",
      "Role",
      "Offices",
      "Status",
      "Joined on"
    ].freeze
    COLUMN_WIDTHS = [24, 24, 20, 30, 20, 16, 18, 24, 12, 14].freeze

    class GenerationError < StandardError; end

    def initialize(month:, members: Member.ordered.includes(:member_office_assignments))
      @month = month.presence || Date.current.strftime("%Y-%m")
      @members = members
    end

    def call
      FileUtils.mkdir_p(output_path.dirname)
      FileUtils.rm_f(output_path)

      Zip::File.open(output_path.to_s, create: true) do |zip|
        write_entry(zip, "[Content_Types].xml", content_types_xml)
        write_entry(zip, "_rels/.rels", root_relationships_xml)
        write_entry(zip, "xl/workbook.xml", workbook_xml)
        write_entry(zip, "xl/_rels/workbook.xml.rels", workbook_relationships_xml)
        write_entry(zip, "xl/styles.xml", styles_xml)
        write_entry(zip, "xl/worksheets/sheet1.xml", worksheet_xml)
      end

      output_path
    rescue StandardError => e
      FileUtils.rm_f(output_path)
      raise GenerationError, "Excel roster generation failed: #{e.message}"
    end

    private

    def output_path
      @output_path ||= Rails.root.join("tmp/reports/member_roster_#{@month}.xlsx")
    end

    def rows
      @rows ||= [HEADERS, *member_rows]
    end

    def member_rows
      @members.map do |member|
        [
          member.display_name,
          member.english_name,
          member.korean_name,
          member.email,
          member.department,
          member.location,
          member.member_role,
          member.office_labels_on(Date.current).join(", "),
          member.active? ? "Active" : "Inactive",
          member.joined_on&.iso8601
        ]
      end
    end

    def write_entry(zip, path, content)
      zip.get_output_stream(path) { |stream| stream.write(content) }
    end

    def content_types_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
      XML
    end

    def root_relationships_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
      XML
    end

    def workbook_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="Members" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
      XML
    end

    def workbook_relationships_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
      XML
    end

    def styles_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="2">
            <font>
              <sz val="11"/>
              <name val="Aptos"/>
            </font>
            <font>
              <b/>
              <sz val="11"/>
              <name val="Aptos"/>
            </font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1">
            <border><left/><right/><top/><bottom/><diagonal/></border>
          </borders>
          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>
          <cellXfs count="2">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
          </cellXfs>
          <cellStyles count="1">
            <cellStyle name="Normal" xfId="0" builtinId="0"/>
          </cellStyles>
        </styleSheet>
      XML
    end

    def worksheet_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <dimension ref="#{sheet_dimension}"/>
          <sheetViews>
            <sheetView workbookViewId="0"/>
          </sheetViews>
          <sheetFormatPr defaultRowHeight="15"/>
          <cols>
            #{column_widths_xml}
          </cols>
          <sheetData>
            #{sheet_rows_xml}
          </sheetData>
          <autoFilter ref="#{sheet_dimension}"/>
        </worksheet>
      XML
    end

    def sheet_dimension
      "A1:#{column_name(HEADERS.length - 1)}#{rows.length}"
    end

    def column_widths_xml
      COLUMN_WIDTHS.each_with_index.map do |width, index|
        %(<col min="#{index + 1}" max="#{index + 1}" width="#{width}" customWidth="1"/>)
      end.join
    end

    def sheet_rows_xml
      rows.each_with_index.map do |values, index|
        row_number = index + 1
        style_index = index.zero? ? 1 : 0
        cells = values.each_with_index.map do |value, cell_index|
          cell_xml("#{column_name(cell_index)}#{row_number}", value, style_index)
        end.join

        %(<row r="#{row_number}">#{cells}</row>)
      end.join
    end

    def cell_xml(reference, value, style_index)
      escaped = CGI.escapeHTML(value.to_s)
      preserve_space = escaped.match?(/\A\s|\s\z/) ? ' xml:space="preserve"' : ""

      %(<c r="#{reference}" t="inlineStr" s="#{style_index}"><is><t#{preserve_space}>#{escaped}</t></is></c>)
    end

    def column_name(index)
      label = +""
      current = index

      while current >= 0
        label.prepend(((current % 26) + 65).chr)
        current = (current / 26) - 1
      end

      label
    end
  end
end
