class Auth::CallbacksController < ApplicationController
  # The callback is reached via browser redirect from Microsoft — no Rails CSRF token.
  # The initiating POST to /auth/entra_id is protected by omniauth-rails_csrf_protection.
  skip_before_action :verify_authenticity_token, only: :entra_id

  def entra_id
    auth  = request.env["omniauth.auth"]
    email = auth.dig("info", "email").to_s.strip.downcase

    user = User.find_by(email: email)

    if user
      reset_session
      session[:user_id] = user.id
      Rails.logger.info "[SSO] Sign-in via Entra ID: user_id=#{user.id} email=#{email}"
      redirect_to root_path, notice: "Signed in with Microsoft successfully."
    else
      Rails.logger.warn "[SSO] Entra ID sign-in rejected — no linked account for email=#{email}"
      redirect_to new_session_path,
        alert: "No Bookclub account is linked to #{email}. Contact an administrator."
    end
  end

  def failure
    message = params[:message].presence || "unknown_error"
    Rails.logger.warn "[SSO] Entra ID authentication failed: #{message}"
    redirect_to new_session_path,
      alert: "Microsoft sign-in failed (#{message.humanize.downcase}). Try again or use local sign-in."
  end
end
