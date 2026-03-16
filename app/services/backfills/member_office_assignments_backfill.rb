module Backfills
  class MemberOfficeAssignmentsBackfill
    Result = Struct.new(:created, :skipped, :warnings, keyword_init: true)

    def initialize(effective_from: nil, dry_run: true, plan_path: MemberOfficeAssignmentPlan::DEFAULT_PATH, replace_existing: false)
      @effective_from = effective_from || default_effective_from
      @dry_run = dry_run
      @plan_path = plan_path
      @replace_existing = replace_existing
    end

    def call
      created = []
      skipped = []
      warnings = []
      plan = MemberOfficeAssignmentPlan.new(path: @plan_path).call
      warnings.concat(plan.warnings)

      Member.find_each do |member|
        assignments, member_warnings = assignment_attributes_for(member, plan.member_assignments[member.id])
        warnings.concat(Array(member_warnings))

        if assignments.blank?
          skipped << member.id
          next
        end

        if @dry_run
          created.concat(assignments.map { |attributes| attributes.merge(member_id: member.id, dry_run: true) })
          next
        end

        member.member_office_assignments.delete_all if @replace_existing

        assignments.each do |attributes|
          assignment = MemberOfficeAssignment.find_or_create_by!(
            member:,
            office_type: attributes[:office_type],
            location: attributes[:location],
            effective_from: attributes[:effective_from]
          ) do |record|
            record.effective_to = attributes[:effective_to]
            record.note = attributes[:note]
          end

          created << { id: assignment.id, member_id: member.id, office_type: assignment.office_type, location: assignment.location }
        end
      end

      Result.new(created:, skipped:, warnings:)
    end

    private

    def assignment_attributes_for(member, planned_assignments)
      return [planned_assignments, []] if planned_assignments.present?

      role_text = member.member_role.to_s
      assignments = []
      warnings = []

      assignments << base_attributes(member, office_type: "chairperson") if role_text.include?("회장")
      assignments << base_attributes(member, office_type: "secretary") if role_text.include?("총무")

      if role_text.include?("Lead")
        if member.location.blank?
          warnings << "Member ##{member.id} (#{member.display_name}) has a leader role but no location for backfill"
        else
          assignments << base_attributes(member, office_type: "site_leader", location: member.location)
        end
      end

      [assignments.uniq, warnings]
    end

    def base_attributes(member, office_type:, location: nil)
      {
        office_type:,
        location:,
        effective_from: @effective_from,
        effective_to: nil,
        note: "Backfilled from member_role '#{member.member_role}'"
      }
    end

    def default_effective_from
      FiscalPeriod.find_by(active: true)&.start_date || Date.current.beginning_of_year
    end
  end
end
