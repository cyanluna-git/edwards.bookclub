module Admin
  class DashboardController < BaseController
    def show
      @fiscal_period_options = FiscalPeriod.active_first
      @filters = params.permit(:fiscal_period_id, :month)
      fiscal_period = selected_fiscal_period
      @dashboard = Admin::DashboardSnapshot.new(
        fiscal_period:,
        month: @filters[:month]
      ).call
    end

    private

    def selected_fiscal_period
      if @filters[:fiscal_period_id].present?
        FiscalPeriod.find_by(id: @filters[:fiscal_period_id])
      else
        FiscalPeriod.find_by(active: true)
      end
    end
  end
end
