module MemberPortal
  class DashboardController < BaseController
    def show
      @snapshot = MemberPortal::DashboardSnapshot.new(member: current_member).call
    end
  end
end
