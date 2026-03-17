class BookRequestLinksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_book_request

  def show
    url = link_url_for(params[:kind])

    if url.present?
      redirect_to url, allow_other_host: true
    else
      redirect_back fallback_location: root_path, alert: "The requested external link is not available."
    end
  end

  private

  def set_book_request
    @book_request =
      if can_manage_club?
        BookRequest.find(params[:book_request_id])
      else
        current_member&.book_requests&.find(params[:book_request_id])
      end

    return if @book_request.present?

    redirect_to root_path, alert: "You are not authorized to access that book request."
  end

  def link_url_for(kind)
    case kind.to_s
    when "purchase" then @book_request.remote_link_url
    when "cover" then @book_request.remote_cover_url
    end
  end
end
