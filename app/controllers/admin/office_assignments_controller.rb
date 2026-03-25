module Admin
  class OfficeAssignmentsController < BaseController
    before_action :set_office_assignment, only: %i[edit update destroy end_assignment]
    before_action :load_form_options, only: %i[index new create edit update]

    def index
      @current_date = Date.current
      @filters = index_filters
      @office_assignments = filtered_office_assignments
      @active_assignments = @office_assignments.select { |assignment| assignment.active_on?(@current_date) }
      @future_assignments = @office_assignments.select { |assignment| assignment.effective_from > @current_date }
      @historical_assignments = @office_assignments.select do |assignment|
        assignment.effective_to.present? && assignment.effective_to < @current_date
      end
    end

    def new
      @office_assignment = MemberOfficeAssignment.new(
        member_id: params[:member_id],
        effective_from: Date.current
      )
    end

    def create
      @office_assignment = MemberOfficeAssignment.new(office_assignment_params)
      @office_assignment.created_by ||= current_user

      if @office_assignment.save
        redirect_to admin_office_assignments_path(member_id: @office_assignment.member_id), notice: "Office assignment created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @office_assignment.update(office_assignment_params)
        redirect_to admin_office_assignments_path(member_id: @office_assignment.member_id), notice: "Office assignment updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      member_id = @office_assignment.member_id
      @office_assignment.destroy!
      redirect_to admin_office_assignments_path(member_id:), notice: "Office assignment deleted."
    end

    def end_assignment
      effective_to = end_assignment_date

      if @office_assignment.update(effective_to:)
        redirect_to admin_office_assignments_path(member_id: @office_assignment.member_id), notice: "Office assignment ended successfully."
      else
        redirect_to admin_office_assignments_path(member_id: @office_assignment.member_id),
          alert: @office_assignment.errors.full_messages.to_sentence
      end
    end

    private

    def set_office_assignment
      @office_assignment = MemberOfficeAssignment.includes(:member).find(params[:id])
    end

    def load_form_options
      @member_options = Member.ordered.map { |member| [member_option_label(member), member.id] }
      @office_type_options = MemberOfficeAssignment::OFFICE_TYPES.map { |key, label| [label, key] }
    end

    def filtered_office_assignments
      relation = MemberOfficeAssignment.includes(:member, :created_by).ordered
      relation = relation.where(member_id: @filters[:member_id]) if @filters[:member_id].present?
      relation = relation.where(office_type: @filters[:office_type]) if @filters[:office_type].present?

      case @filters[:state]
      when "active"
        relation = relation.effective_on(@current_date)
      when "future"
        relation = relation.where("effective_from > ?", @current_date)
      when "history"
        relation = relation.where("effective_to < ?", @current_date)
      end

      relation.to_a
    end

    def index_filters
      {
        member_id: Member.exists?(id: params[:member_id]) ? params[:member_id].to_i : nil,
        office_type: MemberOfficeAssignment::OFFICE_TYPES.key?(params[:office_type].to_s) ? params[:office_type].to_s : nil,
        state: %w[active future history].include?(params[:state].to_s) ? params[:state].to_s : nil
      }
    end

    def office_assignment_params
      params.require(:office_assignment).permit(:member_id, :office_type, :location, :effective_from, :effective_to)
    end

    def end_assignment_date
      raw = params[:effective_to].presence
      raw ? Date.parse(raw) : Date.current
    rescue Date::Error
      @office_assignment.errors.add(:effective_to, "is not a valid date")
      @office_assignment.effective_to
    end

    def member_option_label(member)
      [member.english_name, member.location.presence].compact.join(" · ")
    end
  end
end
