require "yaml"

module Backfills
  class MemberOfficeAssignmentPlan
    DEFAULT_PATH = Rails.root.join("config/bookclub/office_tenures.yml").freeze
    MATCH_KEYS = %w[email source_key english_name korean_name display_name].freeze

    Result = Struct.new(:member_assignments, :warnings, keyword_init: true)

    def initialize(path: DEFAULT_PATH)
      @path = Pathname(path)
    end

    def call
      return Result.new(member_assignments: {}, warnings: []) unless @path.exist?

      payload = YAML.safe_load(@path.read, permitted_classes: [Date], aliases: false) || {}
      warnings = []
      member_assignments = {}

      Array(payload["members"]).each_with_index do |entry, index|
        member = resolve_member(entry)

        unless member
          warnings << "Plan entry ##{index + 1} did not match a member"
          next
        end

        assignments = Array(entry["assignments"]).map do |assignment|
          normalize_assignment(assignment, member)
        end.compact

        if assignments.empty?
          warnings << "Plan entry ##{index + 1} for #{member.display_name} has no assignments"
          next
        end

        member_assignments[member.id] = assignments
      rescue ArgumentError => error
        warnings << "Plan entry ##{index + 1} for #{entry.inspect} is invalid: #{error.message}"
      end

      Result.new(member_assignments:, warnings:)
    end

    private

    def resolve_member(entry)
      matchers = entry.fetch("match", {}).slice(*MATCH_KEYS)
      return if matchers.empty?

      Member.find_by(matchers.transform_keys(&:to_sym))
    end

    def normalize_assignment(assignment, member)
      office_type = assignment.fetch("office_type").to_s
      location = assignment["location"].presence

      {
        office_type:,
        location:,
        effective_from: parse_date!(assignment.fetch("effective_from")),
        effective_to: parse_optional_date(assignment["effective_to"]),
        note: assignment["note"].presence || "Backfilled from office tenure plan for #{member.display_name}"
      }
    end

    def parse_date!(value)
      value.is_a?(Date) ? value : Date.parse(value.to_s)
    end

    def parse_optional_date(value)
      return if value.blank?

      parse_date!(value)
    end
  end
end
