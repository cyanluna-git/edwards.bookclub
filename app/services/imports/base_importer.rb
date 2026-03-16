require "csv"

module Imports
  class BaseImporter
    attr_reader :path, :result

    def initialize(path)
      @path = path
      @result = Result.new(name: self.class.name.demodulize)
    end

    private

    def each_row
      CSV.foreach(path, headers: true, encoding: "bom|utf-8") do |row|
        yield row.to_h.transform_values { |value| value.is_a?(String) ? value.strip : value }
      end
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def parse_date(value)
      return if blank?(value)

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end

    def parse_datetime(value)
      return if blank?(value)

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_decimal(value)
      return if blank?(value)

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def parse_boolean(value)
      return false if blank?(value)

      normalized = value.to_s.strip.downcase
      %w[true 1 yes y].include?(normalized)
    end

    def normalize_text(value)
      value.to_s.strip.presence
    end

    def fiscal_period_for(date_or_time)
      return if date_or_time.blank?

      date = date_or_time.to_date
      FiscalPeriod.where("start_date <= ? AND end_date >= ?", date, date)
                  .order(active: :desc, start_date: :desc)
                  .first
    end

    def member_from_lookup(source_id:, display_name:)
      member = Member.find_by(source_system: "sharepoint_members", source_key: source_id.to_s) if source_id.present?
      return member if member

      Member.find_by(english_name: display_name) ||
        Member.find_by(korean_name: display_name)
    end
  end
end
