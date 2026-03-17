module Admin
  class MemberAccessesController < BaseController
    before_action :set_member

    def create
      upsert_user_access(@member.build_user)
    end

    def update
      upsert_user_access(@member.user)
    end

    def destroy
      user = @member.user

      if user
        user.destroy!
        redirect_to admin_member_path(@member), notice: "Linked access removed."
      else
        redirect_to admin_member_path(@member), alert: "No linked access exists for this member."
      end
    end

    private

    def set_member
      @member = Member.includes(:user, :member_office_assignments).find(params[:member_id])
    end

    def upsert_user_access(user)
      if email_taken_by_other_member?(user_access_params[:email], user)
        redirect_to admin_member_path(@member), alert: "That email is already linked to another member account."
        return
      end

      user.email = user_access_params[:email]
      user.role = user_access_params[:role]
      user.member = @member

      if password_present?
        user.password = user_access_params[:password]
        user.password_confirmation = user_access_params[:password_confirmation]
      elsif user.new_record?
        user.errors.add(:password, "can't be blank")
      end

      if user.errors.empty? && user.save
        redirect_to admin_member_path(@member), notice: user.previously_new_record? ? "Linked access created." : "Linked access updated."
      else
        redirect_to admin_member_path(@member), alert: user.errors.full_messages.to_sentence
      end
    end

    def email_taken_by_other_member?(email, current_user)
      return false if email.blank?

      existing = User.find_by(email: email.strip.downcase)
      existing.present? && existing != current_user && existing.member_id.present? && existing.member_id != @member.id
    end

    def password_present?
      user_access_params[:password].present? || user_access_params[:password_confirmation].present?
    end

    def user_access_params
      raw = params.require(:user_access)

      {
        email: raw[:email].to_s.strip.downcase,
        role: User::ROLES.include?(raw[:role].to_s) ? raw[:role].to_s : nil,
        password: raw[:password].to_s,
        password_confirmation: raw[:password_confirmation].to_s
      }
    end
  end
end
