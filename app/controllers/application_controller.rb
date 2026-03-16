class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_request_context

  helper_method :current_user, :current_member, :authenticated?

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.includes(:member).find_by(id: session[:user_id])
  end

  def current_member
    current_user&.member
  end

  def authenticated?
    current_user.present?
  end

  def authenticate_user!
    return if authenticated?

    redirect_to new_session_path, alert: "Please sign in to continue."
  end

  def require_admin!
    authenticate_user!
    return if performed? || current_user&.admin?

    redirect_to root_path, alert: "You are not authorized to access that page."
  end

  def set_current_request_context
    Current.user = current_user
    Current.member = current_member
  end
end
