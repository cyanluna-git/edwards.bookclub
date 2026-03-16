class HomeController < ApplicationController
  before_action :authenticate_user!

  def show
    return redirect_to admin_dashboard_path if current_user.admin?

    redirect_to member_root_path
  end
end
