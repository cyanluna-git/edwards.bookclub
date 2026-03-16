class SessionsController < ApplicationController
  before_action :redirect_authenticated_user, only: %i[new create]

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

  def destroy
    reset_session
    redirect_to new_session_path, notice: "Signed out successfully."
  end

  private

  def redirect_authenticated_user
    redirect_to root_path if authenticated?
  end
end
