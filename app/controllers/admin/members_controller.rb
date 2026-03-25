module Admin
  class MembersController < BaseController
    skip_before_action :require_admin!, only: %i[index new create]
    before_action :require_member_management_access!, only: %i[index new create]
    before_action :set_member, only: %i[show edit update deactivate reactivate]
    before_action :load_filter_options, only: %i[index new create edit update show]

    def index
      @filters = index_filters
      @members = Member
        .filter(@filters)
        .includes(:user, :member_office_assignments, :meeting_attendances, :book_requests)
      @summary = {
        total: Member.count,
        active: Member.where(active: true).count,
        inactive: Member.where(active: false).count,
        linked_access: User.where.not(member_id: nil).count,
        managers: User.includes(member: :member_office_assignments).count(&:can_manage_club?)
      }
    end

    def show
    end

    def new
      @member = Member.new(active: true)
    end

    def create
      @member = Member.new(member_params)

      if @member.save
        redirect_to(post_create_redirect_path, notice: "Member created successfully.")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @member.update(member_params)
        redirect_to admin_member_path(@member), notice: "Member updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def deactivate
      @member.update!(active: false)
      redirect_to admin_member_path(@member), notice: "Member marked inactive."
    end

    def reactivate
      @member.update!(active: true)
      redirect_to admin_member_path(@member), notice: "Member reactivated."
    end

    private

    def set_member
      @member = Member.includes(:user, :meeting_attendances, :book_requests).find(params[:id])
    end

    def member_params
      params.require(:member).permit(:english_name, :korean_name, :department, :email, :member_role, :location, :joined_on, :bio, :active)
    end

    def load_filter_options
      @role_options = Member.role_options
      @location_options = Member.location_options
    end

    def index_filters
      {
        q: params[:q].to_s,
        active: %w[active inactive].include?(params[:active].to_s) ? params[:active].to_s : nil,
        role: @role_options.include?(params[:role].to_s) ? params[:role].to_s : nil,
        location: @location_options.include?(params[:location].to_s) ? params[:location].to_s : nil
      }
    end

    def post_create_redirect_path
      can_manage_club? ? admin_member_path(@member) : admin_members_path
    end
  end
end
