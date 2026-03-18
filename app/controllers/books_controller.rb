class BooksController < ApplicationController
  before_action :authenticate_user!

  def index
    scope = BookRequest.includes(:member, :fiscal_period).order(requested_on: :desc, id: :desc)
    scope = scope.where(fiscal_period_id: params[:fiscal_period_id]) if params[:fiscal_period_id].present?
    @book_requests = scope
    @fiscal_period_options = FiscalPeriod.order(start_date: :desc)
  end
end
