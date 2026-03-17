module Auth
  class SsoConfiguration
    DEFAULT_EMAIL_HEADERS = %w[
      X-Forwarded-Email
      X-Auth-Request-Email
      X-MS-CLIENT-PRINCIPAL-NAME
      X-Email
    ].freeze

    class << self
      def enabled?
        boolean_env("BOOKCLUB_SSO_ENABLED")
      end

      def auto_redirect?
        boolean_env("BOOKCLUB_SSO_AUTO_REDIRECT")
      end

      def login_url
        ENV["BOOKCLUB_SSO_LOGIN_URL"].to_s.strip.presence
      end

      def shared_secret
        ENV["BOOKCLUB_SSO_SHARED_SECRET"].to_s.presence
      end

      def max_age_seconds
        value = ENV.fetch("BOOKCLUB_SSO_MAX_AGE_SECONDS", "300").to_i
        value.positive? ? value : 300
      end

      def email_headers
        configured = ENV["BOOKCLUB_SSO_EMAIL_HEADERS"].to_s.split(",").map { |value| value.strip.presence }.compact
        configured.presence || DEFAULT_EMAIL_HEADERS
      end

      private

      def boolean_env(key)
        ActiveModel::Type::Boolean.new.cast(ENV[key])
      end
    end
  end
end
