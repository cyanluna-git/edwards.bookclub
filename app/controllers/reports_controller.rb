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

  def create_outlook_draft
    report_params = { fiscal_period_id: params[:fiscal_period_id], month: params[:month] }
    generated_paths = []

    unless current_user.microsoft_access_token.present?
      redirect_to reports_path(**report_params), alert: "Microsoft 계정 연동이 필요합니다. SSO로 다시 로그인해 주세요."
      return
    end

    fiscal_period = selected_fiscal_period
    month = params[:month]
    config = Reports::EmailConfig

    docx_path = Reports::MonthlyDocxGenerator.new(fiscal_period:, month:).call
    generated_paths << docx_path
    roster_path = Reports::MemberRosterXlsxGenerator.new(month:).call
    generated_paths << roster_path

    dashboard = Admin::DashboardSnapshot.new(fiscal_period:, month:).call

    result = Integrations::MicrosoftGraph::DraftMailer.call(
      user: current_user,
      subject: config.subject(month:),
      body_html: config.body_html(
        month:,
        meeting_count: dashboard.meeting_digests.size,
        attendance_count: dashboard.location_breakdown.sum(&:count)
      ),
      to_recipients: config.default_to_recipients,
      cc_recipients: config.default_cc_recipients,
      attachments: [
        { path: docx_path, name: "월간보고서_#{month}.docx" },
        { path: roster_path, name: "회원명단_#{month}.xlsx" }
      ]
    )

    if result.success
      if result.web_link.present?
        redirect_to result.web_link, allow_other_host: true
      else
        redirect_to reports_path(**report_params), notice: "Outlook 초안이 생성되었습니다. Outlook 초안함에서 확인 후 전송하세요."
      end
    else
      redirect_to reports_path(**report_params), alert: "초안 생성 실패: #{result.error}"
    end
  rescue Reports::MonthlyDocxGenerator::GenerationError => e
    Rails.logger.error("DOCX generation for Outlook draft failed: #{e.message}")
    redirect_to reports_path(fiscal_period_id: params[:fiscal_period_id], month: params[:month]),
                alert: "DOCX 생성에 실패했습니다. 다시 시도해 주세요."
  rescue Reports::MemberRosterXlsxGenerator::GenerationError => e
    Rails.logger.error("Member roster Excel generation failed: #{e.message}")
    redirect_to reports_path(fiscal_period_id: params[:fiscal_period_id], month: params[:month]),
                alert: "회원 명단 Excel 생성에 실패했습니다. 다시 시도해 주세요."
  ensure
    generated_paths.each { |path| FileUtils.rm_f(path) if path.present? }
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
