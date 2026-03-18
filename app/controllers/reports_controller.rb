class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_filters

  def show
    @fiscal_period_options = FiscalPeriod.active_first
    fiscal_period = selected_fiscal_period
    @dashboard = Admin::DashboardSnapshot.new(
      fiscal_period:,
      month: @filters[:month]
    ).call
    @filters[:month] = @dashboard.selected_month_value
  end

  def generate_docx
    fiscal_period = selected_fiscal_period
    month = params[:month]

    docx_path = Reports::MonthlyDocxGenerator.new(fiscal_period:, month:).call

    send_file docx_path,
              type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
              filename: "월간보고서_#{month}.docx",
              disposition: "attachment"
  rescue Reports::MonthlyDocxGenerator::GenerationError => e
    Rails.logger.error("DOCX generation failed: #{e.message}")
    redirect_to reports_path(fiscal_period_id: params[:fiscal_period_id], month: params[:month]),
                alert: "DOCX 생성에 실패했습니다. 다시 시도해 주세요."
  end

  private

  def set_filters
    @filters = params.permit(:fiscal_period_id, :month).to_h.symbolize_keys
  end

  def selected_fiscal_period
    if @filters[:fiscal_period_id].present?
      FiscalPeriod.find_by(id: @filters[:fiscal_period_id])
    else
      FiscalPeriod.find_by(active: true)
    end
  end
end
