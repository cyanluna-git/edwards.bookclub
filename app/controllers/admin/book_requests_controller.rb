module Admin
  class BookRequestsController < BaseController
    before_action :set_book_request, only: %i[show edit update destroy]
    before_action :load_options, only: %i[index show new create edit update]
    before_action :prepare_aladin_lookup, only: %i[new create edit update]

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
        member: default_requesting_member,
        fiscal_period: FiscalPeriod.find_by(active: true),
        requested_on: Date.current,
        request_status: BookRequest.status_options.first
      )
      apply_prefill(@book_request)
    end

    def create
      @book_request = BookRequest.new(book_request_params)
      @book_request.member ||= default_requesting_member

      if @book_request.save
        redirect_to admin_book_request_path(@book_request), notice: "Book request created successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      apply_prefill(@book_request)
    end

    def update
      if @book_request.update(book_request_params)
        redirect_to admin_book_request_path(@book_request), notice: "Book request updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @book_request.destroy!
      redirect_to books_path, notice: "Book request cancelled."
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

    def prepare_aladin_lookup
      @aladin_query = params[:aladin_query].to_s.strip
      @aladin_lookup = Integrations::Aladin::BookSearch.call(query: @aladin_query)
      @aladin_search_path = if action_name == "edit" || params[:id].present?
        edit_admin_book_request_path(params[:id] || @book_request)
      else
        new_admin_book_request_path
      end
    end

    def apply_prefill(book_request)
      return if prefill_params.blank?

      book_request.assign_attributes(prefill_params.to_h)
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

    def prefill_params
      params.fetch(:prefill, ActionController::Parameters.new).permit(:title, :author, :publisher, :price, :cover_url, :link_url)
    end

    def default_requesting_member
      current_user&.member
    end
  end
end
