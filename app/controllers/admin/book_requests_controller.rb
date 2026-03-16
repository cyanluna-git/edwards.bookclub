module Admin
  class BookRequestsController < BaseController
    before_action :set_book_request, only: %i[show edit update]
    before_action :load_options, only: %i[index show new create edit update]

    def index
      @filters = filter_params
      @book_requests = BookRequest.filter(@filters).includes(:member, :fiscal_period)
      @reserve_snapshot = Admin::ReserveSnapshot.new(fiscal_period: reserve_snapshot_period).call
      @list_summary = {
        count: @book_requests.count,
        total_price: @book_requests.sum(:price).to_d,
        total_additional_payment: @book_requests.sum(:additional_payment).to_d
      }
    end

    def show
    end

    def new
      @book_request = BookRequest.new(
        fiscal_period: FiscalPeriod.find_by(active: true),
        requested_on: Date.current,
        request_status: BookRequest.status_options.first
      )
    end

    def create
      @book_request = BookRequest.new(book_request_params)

      if @book_request.save
        redirect_to admin_book_request_path(@book_request), notice: "Book request created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @book_request.update(book_request_params)
        redirect_to admin_book_request_path(@book_request), notice: "Book request updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_book_request
      @book_request = BookRequest.includes(:member, :fiscal_period).find(params[:id])
    end

    def load_options
      @member_options = Member.ordered
      @status_options = BookRequest.status_options
      @fiscal_period_options = FiscalPeriod.active_first
    end

    def filter_params
      params.permit(:q, :member_id, :request_status, :fiscal_period_id, :requested_from, :requested_to)
    end

    def reserve_snapshot_period
      if filter_params[:fiscal_period_id].present?
        FiscalPeriod.find_by(id: filter_params[:fiscal_period_id])
      else
        FiscalPeriod.find_by(active: true)
      end
    end

    def book_request_params
      params.require(:book_request).permit(
        :member_id,
        :title,
        :author,
        :publisher,
        :price,
        :request_status,
        :cover_url,
        :link_url,
        :comment,
        :rating,
        :requested_on,
        :additional_payment,
        :fiscal_period_id
      )
    end
  end
end
