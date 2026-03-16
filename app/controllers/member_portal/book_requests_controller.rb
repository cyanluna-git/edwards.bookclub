module MemberPortal
  class BookRequestsController < BaseController
    before_action :require_linked_member!
    before_action :set_book_request, only: %i[show edit update]

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
    end

    def update
      if @book_request.update(member_book_request_params)
        redirect_to member_book_request_path(@book_request), notice: "Book request updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def require_linked_member!
      return if current_member

      redirect_to member_root_path, alert: "Your account is not linked to a member profile yet."
    end

    def set_book_request
      @book_request = current_member.book_requests.includes(:fiscal_period).find(params[:id])
    end

    def member_book_request_params
      params.require(:book_request).permit(
        :title,
        :author,
        :publisher,
        :cover_url,
        :link_url,
        :comment,
        :rating,
        :requested_on,
        :fiscal_period_id
      )
    end
  end
end
