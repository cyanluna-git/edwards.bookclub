require "json"
require "net/http"
require "uri"
require "base64"

module Integrations
  module MicrosoftGraph
    class DraftMailer
      GRAPH_BASE = "https://graph.microsoft.com/v1.0".freeze

      Result = Struct.new(:success, :draft_id, :web_link, :error, keyword_init: true)

      def self.call(user:, subject:, body_html:, to_recipients: [], attachment_path: nil)
        new(user:, subject:, body_html:, to_recipients:, attachment_path:).call
      end

      def initialize(user:, subject:, body_html:, to_recipients: [], attachment_path: nil)
        @user = user
        @subject = subject
        @body_html = body_html
        @to_recipients = to_recipients
        @attachment_path = attachment_path
        @retried = false
      end

      def call
        token = @user.ensure_valid_microsoft_token!
        draft = create_draft(token)
        add_attachment(token, draft["id"]) if @attachment_path && File.exist?(@attachment_path)

        Result.new(
          success: true,
          draft_id: draft["id"],
          web_link: draft["webLink"]
        )
      rescue OAuth2::Error, RuntimeError => e
        Rails.logger.error("[Graph API] #{e.class}: #{e.message}")
        if !@retried && e.message.include?("refresh")
          @retried = true
          retry
        end
        Result.new(success: false, error: e.message)
      rescue StandardError => e
        Rails.logger.error("[Graph API] #{e.class}: #{e.message}")
        Result.new(success: false, error: e.message)
      end

      private

      def create_draft(token)
        uri = URI("#{GRAPH_BASE}/me/messages")
        payload = {
          subject: @subject,
          body: { contentType: "HTML", content: @body_html },
          toRecipients: build_recipients,
          isDraft: true
        }

        response = graph_post(uri, token, payload)
        handle_response(response, "draft creation")
      end

      def add_attachment(token, message_id)
        uri = URI("#{GRAPH_BASE}/me/messages/#{message_id}/attachments")
        file_content = File.binread(@attachment_path)
        filename = File.basename(@attachment_path)

        payload = {
          "@odata.type": "#microsoft.graph.fileAttachment",
          name: filename,
          contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          contentBytes: Base64.strict_encode64(file_content)
        }

        response = graph_post(uri, token, payload)
        handle_response(response, "attachment")
      end

      def build_recipients
        @to_recipients.map do |r|
          {
            emailAddress: {
              address: r[:email] || r["email"],
              name: r[:name] || r["name"] || ""
            }
          }
        end
      end

      def graph_post(uri, token, payload)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 30

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        http.request(request)
      end

      def handle_response(response, context)
        case response.code.to_i
        when 200..299
          JSON.parse(response.body)
        when 401
          raise "Microsoft token expired during #{context}. Please sign in with SSO again."
        when 403
          raise "Mail.ReadWrite 권한이 없습니다. Azure 관리자에게 문의하세요."
        else
          body = begin
            JSON.parse(response.body)
          rescue JSON::ParserError
            {}
          end
          message = body.dig("error", "message") || response.body.to_s.truncate(200)
          raise "Graph API #{context} failed (#{response.code}): #{message}"
        end
      end
    end
  end
end
