require "test_helper"

module Integrations
  module MicrosoftGraph
    class DraftMailerTest < ActiveSupport::TestCase
      FakeResponse = Struct.new(:code, :body, keyword_init: true)

      class FakeHTTP
        attr_accessor :use_ssl, :open_timeout, :read_timeout
        attr_reader :requests

        def initialize(responses)
          @responses = responses
          @requests = []
        end

        def request(request)
          @requests << request
          @responses.shift || raise("No fake response configured")
        end
      end

      setup do
        @user = Object.new
        @user.define_singleton_method(:ensure_valid_microsoft_token!) { "access-token" }

        @docx_path = Rails.root.join("tmp/reports/draft_mailer_test.docx")
        @xlsx_path = Rails.root.join("tmp/reports/draft_mailer_test.xlsx")
        FileUtils.mkdir_p(@docx_path.dirname)
        File.binwrite(@docx_path, "docx-body")
        File.binwrite(@xlsx_path, "xlsx-body")
      end

      teardown do
        FileUtils.rm_f(@docx_path)
        FileUtils.rm_f(@xlsx_path)
      end

      test "creates a draft with cc recipients and uploads multiple attachments" do
        responses = [
          FakeResponse.new(code: "201", body: { id: "draft-123", webLink: "https://outlook.example.test/draft-123" }.to_json),
          FakeResponse.new(code: "201", body: "{}"),
          FakeResponse.new(code: "201", body: "{}")
        ]
        fake_http = FakeHTTP.new(responses)
        original_new = Net::HTTP.method(:new)

        Net::HTTP.define_singleton_method(:new) { |_host, _port| fake_http }

        result = DraftMailer.call(
          user: @user,
          subject: "에드워즈 독서모임 2026-03 활동 보고서",
          body_html: "<p>보고서를 첨부합니다.</p>",
          to_recipients: [ { email: "alieen.yoon@edwardsvacuum.com", name: "Alieen Yoon" } ],
          cc_recipients: [
            { email: "qj.lee@csk.kr", name: "QJ Lee" },
            { email: "blake.jung@edwardsvacuum.com", name: "Blake Jung" }
          ],
          attachments: [
            { path: @docx_path, name: "월간보고서_2026-03.docx" },
            { path: @xlsx_path, name: "회원명단_2026-03.xlsx" }
          ]
        )

        assert result.success
        assert_equal "draft-123", result.draft_id
        assert_equal 3, fake_http.requests.size

        draft_payload = JSON.parse(fake_http.requests[0].body)
        assert_equal "에드워즈 독서모임 2026-03 활동 보고서", draft_payload["subject"]
        assert_equal "alieen.yoon@edwardsvacuum.com", draft_payload.dig("toRecipients", 0, "emailAddress", "address")
        assert_equal 2, draft_payload["ccRecipients"].size
        assert_equal "/v1.0/me/messages", fake_http.requests[0].path

        docx_payload = JSON.parse(fake_http.requests[1].body)
        assert_equal "월간보고서_2026-03.docx", docx_payload["name"]
        assert_equal "application/vnd.openxmlformats-officedocument.wordprocessingml.document", docx_payload["contentType"]
        assert_equal "/v1.0/me/messages/draft-123/attachments", fake_http.requests[1].path

        xlsx_payload = JSON.parse(fake_http.requests[2].body)
        assert_equal "회원명단_2026-03.xlsx", xlsx_payload["name"]
        assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", xlsx_payload["contentType"]
      ensure
        Net::HTTP.define_singleton_method(:new, original_new) if original_new
      end
    end
  end
end
