module Admin
  class FiscalPeriodsController < BaseController
    before_action :set_fiscal_period, only: %i[show edit update]

    def index
      @fiscal_periods = FiscalPeriod.active_first
    end

    def show
    end

    def new
      @fiscal_period = FiscalPeriod.new(active: false)
    end

    def create
      @fiscal_period = FiscalPeriod.new(fiscal_period_params)

      if @fiscal_period.save
        redirect_to admin_fiscal_period_path(@fiscal_period), notice: "Fiscal period created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @fiscal_period.update(fiscal_period_params)
        redirect_to admin_fiscal_period_path(@fiscal_period), notice: "Fiscal period updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_fiscal_period
      @fiscal_period = FiscalPeriod.find(params[:id])
    end

    def fiscal_period_params
      params.require(:fiscal_period).permit(:name, :start_date, :end_date, :active)
    end
  end
end
