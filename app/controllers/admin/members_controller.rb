module Admin
  class MembersController < BaseController
    before_action :set_member, only: %i[show edit update deactivate reactivate]
    before_action :load_filter_options, only: %i[index new create edit update show]

    def index
      @filters = index_filters
      @members = Member.filter(@filters).includes(:user, :meeting_attendances, :book_requests)
      @summary = {
        total: Member.count,
        active: Member.where(active: true).count,
        inactive: Member.where(active: false).count
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
        redirect_to admin_member_path(@member), notice: "Member created successfully."
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
      params.permit(:q, :active, :role, :location)
    end
  end
end
