module Imports
  class Result
    attr_reader :name, :counts, :skipped, :warnings, :errors

    def initialize(name:)
      @name = name
      @counts = Hash.new(0)
      @skipped = []
      @warnings = []
      @errors = []
    end

    def imported(kind)
      @counts["#{kind}_imported"] += 1
    end

    def updated(kind)
      @counts["#{kind}_updated"] += 1
    end

    def skipped!(kind, row_identifier:, reason:)
      @counts["#{kind}_skipped"] += 1
      @skipped << { kind:, row_identifier:, reason: }
    end

    def warn!(kind, row_identifier:, reason:)
      @warnings << { kind:, row_identifier:, reason: }
    end

    def error!(kind, row_identifier:, reason:)
      @counts["#{kind}_errors"] += 1
      @errors << { kind:, row_identifier:, reason: }
    end

    def merge!(other)
      other.counts.each { |key, value| @counts[key] += value }
      @skipped.concat(other.skipped)
      @warnings.concat(other.warnings)
      @errors.concat(other.errors)
      self
    end

    def success?
      errors.empty?
    end

    def to_h
      {
        name:,
        counts: counts.sort.to_h,
        skipped:,
        warnings:,
        errors:
      }
    end
  end
end
