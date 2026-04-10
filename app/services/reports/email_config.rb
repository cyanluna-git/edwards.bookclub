module Reports
  class EmailConfig
    CONFIG_PATH = Rails.root.join("config/report_email.yml").freeze

    def self.load
      return default_config unless CONFIG_PATH.exist?

      config = YAML.safe_load(CONFIG_PATH.read, permitted_classes: [], symbolize_names: true)
      config || default_config
    rescue Psych::SyntaxError => e
      Rails.logger.warn("Failed to parse report email config: #{e.message}")
      default_config
    end

    def self.default_recipients
      default_to_recipients
    end

    def self.default_to_recipients
      recipient_list(:default_to_recipients, fallback_key: :default_recipients)
    end

    def self.default_cc_recipients
      recipient_list(:default_cc_recipients)
    end

    def self.subject(month:)
      template = load[:subject_template] || default_config[:subject_template]
      format(template, month: month)
    end

    def self.body_html(month:, meeting_count: 0, attendance_count: 0)
      template = load[:body_template] || default_config[:body_template]
      format(template, month: month, meeting_count: meeting_count, attendance_count: attendance_count)
    end

    def self.default_config
      {
        default_to_recipients: [],
        default_cc_recipients: [],
        default_recipients: [],
        subject_template: "에드워즈 독서모임 %{month} 활동 보고서",
        body_template: "<p>에드워즈 독서모임 %{month} 활동 보고서를 첨부합니다.</p>"
      }
    end

    def self.recipient_list(key, fallback_key: nil)
      config = load
      recipients = config[key]
      recipients = config[fallback_key] if recipients.blank? && fallback_key
      return [] unless recipients.is_a?(Array)

      recipients.filter_map do |recipient|
        next unless recipient.is_a?(Hash) && recipient[:email].present?

        { email: recipient[:email], name: recipient[:name] || "" }
      end
    end
  end
end
