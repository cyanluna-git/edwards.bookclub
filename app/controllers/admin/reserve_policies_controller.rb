module Admin
  class ReservePoliciesController < BaseController
    before_action :set_reserve_policy, only: %i[show edit update]

    def index
      @reserve_policies = ReservePolicy.ordered
    end

    def show
    end

    def new
      @reserve_policy = ReservePolicy.new
    end

    def create
      @reserve_policy = ReservePolicy.new(reserve_policy_params)

      if @reserve_policy.save
        redirect_to admin_reserve_policy_path(@reserve_policy), notice: "Reserve policy created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @reserve_policy.update(reserve_policy_params)
        redirect_to admin_reserve_policy_path(@reserve_policy), notice: "Reserve policy updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_reserve_policy
      @reserve_policy = ReservePolicy.find(params[:id])
    end

    def reserve_policy_params
      params.require(:reserve_policy).permit(:member_role, :attendance_points, :effective_from, :effective_to)
    end
  end
end
