module Auth
  class SsoSessionResolver
    Result = Struct.new(:status, :user, :email, :redirect_url, :message, keyword_init: true) do
      def success?
        status == :success
      end
    end

    def initialize(request:, params:)
      @request = request
      @params = params
    end

    def resolve
      return disabled_result unless SsoConfiguration.enabled?

      email = resolved_email
      return redirect_result if email.blank? && SsoConfiguration.login_url.present?
      return missing_identity_result if email.blank?

      user = User.find_or_provision_from_sso(email)
      return success_result(user, email) if user.present?

      unlinked_result(email)
    end

    private

    attr_reader :request, :params

    def resolved_email
      header_email.presence || verified_param_email.presence
    end

    def header_email
      SsoConfiguration.email_headers.lazy.map { |header| request.headers[header].to_s.strip.downcase.presence }.find(&:present?)
    end

    def verified_param_email
      email = params[:email].to_s.strip.downcase
      return if email.blank?
      return email if Rails.env.development? || Rails.env.test?

      secret = SsoConfiguration.shared_secret
      timestamp = Integer(params[:ts], exception: false)
      signature = params[:sig].to_s
      return if secret.blank? || timestamp.blank? || signature.blank?
      return if (Time.current.to_i - timestamp).abs > SsoConfiguration.max_age_seconds

      payload = "#{email}:#{timestamp}"
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
      return unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)

      email
    end

    def disabled_result
      Result.new(status: :disabled, message: "SSO is not enabled for this environment.")
    end

    def redirect_result
      Result.new(status: :redirect, redirect_url: SsoConfiguration.login_url)
    end

    def missing_identity_result
      Result.new(status: :missing_identity, message: "SSO identity was not provided by the upstream login flow.")
    end

    def unlinked_result(email)
      Result.new(status: :unlinked, email:, message: "The SSO email #{email} is not linked to an active book club member.")
    end

    def success_result(user, email)
      Result.new(status: :success, user:, email:, message: "Signed in with SSO.")
    end
  end
end
