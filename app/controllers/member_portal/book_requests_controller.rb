module MemberPortal
  class BookRequestsController < BaseController
    before_action :require_linked_member!
    before_action :set_book_request, only: %i[show edit update destroy]
    before_action :prepare_aladin_lookup, only: %i[new create edit update]

    def index
      @book_requests = current_member.book_requests.ordered_recent.includes(:fiscal_period)
    end

    def show
    end

    def new
      @book_request = current_member.book_requests.build(
        fiscal_period: FiscalPeriod.find_by(active: true),
        requested_on: Date.current,
        request_status: "Requested"
      )
      apply_prefill(@book_request)
    end

    def create
      @book_request = current_member.book_requests.build(member_book_request_params)
      @book_request.request_status = @book_request.request_status.presence || "Requested"

      if @book_request.save
        redirect_to member_book_request_path(@book_request), notice: "Book request submitted successfully."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      apply_prefill(@book_request)
    end

    def update
      if @book_request.update(member_book_request_params)
        redirect_to member_book_request_path(@book_request), notice: "Book request updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @book_request.destroy!
      redirect_to member_book_requests_path, notice: "Book request deleted successfully."
    end

    private

    def require_linked_member!
      return if current_member

      redirect_to member_root_path, alert: "Your account is not linked to a member profile yet."
    end

    def set_book_request
      @book_request = current_member.book_requests.includes(:fiscal_period).find(params[:id])
    end

    def prepare_aladin_lookup
      @aladin_query = params[:aladin_query].to_s.strip
      @aladin_lookup = Integrations::Aladin::BookSearch.call(query: @aladin_query)
      @aladin_search_path = if action_name == "edit" || params[:id].present?
        edit_member_book_request_path(params[:id] || @book_request)
      else
        new_member_book_request_path
      end
    end

    def apply_prefill(book_request)
      return if prefill_params.blank?

      book_request.assign_attributes(prefill_params.to_h)
    end

    def member_book_request_params
      params.require(:book_request).permit(
        :title,
        :author,
        :publisher,
        :price,
        :cover_url,
        :link_url,
        :comment,
        :rating,
        :requested_on,
        :fiscal_period_id
      )
    end

    def prefill_params
      params.fetch(:prefill, ActionController::Parameters.new).permit(:title, :author, :publisher, :price, :cover_url, :link_url)
    end
  end
end
