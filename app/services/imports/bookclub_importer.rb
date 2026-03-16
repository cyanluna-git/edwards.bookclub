module Imports
  class BookclubImporter
    DEFAULT_MEMBERS_CSV = Rails.root.join("artifacts/csv/Members.csv").freeze

    def initialize(members_csv: nil, book_requests_csv: nil, attendance_csv: nil)
      @members_csv = members_csv.presence || default_path(DEFAULT_MEMBERS_CSV)
      @book_requests_csv = book_requests_csv.presence
      @attendance_csv = attendance_csv.presence
    end

    def call
      result = Result.new(name: "BookclubImporter")

      result.merge!(import_file(@members_csv, MembersImporter))
      result.merge!(import_file(@book_requests_csv, BookRequestsImporter))
      result.merge!(import_file(@attendance_csv, AttendancesImporter))

      result
    end

    private

    def default_path(pathname)
      pathname.exist? ? pathname.to_s : nil
    end

    def import_file(path, importer_class)
      return Result.new(name: importer_class.name.demodulize) if path.blank?

      unless File.exist?(path)
        missing_result = Result.new(name: importer_class.name.demodulize)
        missing_result.error!(:file, row_identifier: path, reason: "source file not found")
        return missing_result
      end

      importer_class.new(path).call
    end
  end
end
