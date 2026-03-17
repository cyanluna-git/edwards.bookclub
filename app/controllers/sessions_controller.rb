class SessionsController < ApplicationController
  before_action :redirect_authenticated_user, only: %i[new create sso]
  before_action :attempt_sso_sign_in, only: :new

  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password].to_s)
      session[:user_id] = user.id
      redirect_to root_path, notice: "Signed in successfully."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_content
    end
  end

  def sso
    result = sso_result

    if result.success?
      complete_sign_in(result.user, notice: result.message)
    elsif result.redirect_url.present?
      redirect_to result.redirect_url, allow_other_host: true
    else
      redirect_to new_session_path, alert: result.message
    end
  end

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Signed out successfully."
  end

  private

  def attempt_sso_sign_in
    return unless sso_enabled?

    result = sso_result

    if result.success?
      complete_sign_in(result.user, notice: result.message)
    elsif result.redirect_url.present? && sso_auto_redirect?
      redirect_to result.redirect_url, allow_other_host: true
    end
  end

  def sso_result
    @sso_result ||= Auth::SsoSessionResolver.new(request:, params:).resolve
  end

  def complete_sign_in(user, notice:)
    reset_session
    session[:user_id] = user.id
    redirect_to root_path, notice:
  end

  def redirect_authenticated_user
    redirect_to root_path if authenticated?
  end
end
