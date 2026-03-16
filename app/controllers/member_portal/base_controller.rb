module MemberPortal
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_member_user!

    private

    def require_member_user!
      return redirect_to admin_dashboard_path if can_manage_club?
      return if current_user.member?

      redirect_to root_path, alert: "You are not authorized to access that page."
    end
  end
end
