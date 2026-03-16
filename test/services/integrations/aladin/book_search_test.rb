require "test_helper"
require "ostruct"

module Integrations
  module Aladin
    class BookSearchTest < ActiveSupport::TestCase
      test "returns disabled result when ttb key is missing" do
        result = BookSearch.call(query: "Atomic Habits", ttb_key: "", http_get: ->(*) { raise "should not call http" })

        assert_not result.enabled?
        assert_equal "Atomic Habits", result.query
        assert_empty result.items
        assert_match "ALADIN_TTB_KEY", result.error_message
      end

      test "parses successful responses into normalized items" do
        requested_uri = nil
        response = OpenStruct.new(
          code: "200",
          body: {
            item: [
              {
                title: "Atomic Habits",
                author: "James Clear",
                publisher: "Avery",
                cover: "https://example.com/atomic.jpg",
                link: "https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=1",
                isbn13: "9780735211292",
                pubDate: "2024-01-10",
                priceSales: 18000
              }
            ]
          }.to_json
        )

        result = BookSearch.call(
          query: "Atomic Habits",
          ttb_key: "test-key",
          http_get: lambda { |uri|
            requested_uri = uri
            response
          }
        )

        assert result.enabled?
        assert_nil result.error_message
        assert_equal "Atomic Habits", result.items.first.title
        assert_equal "James Clear", result.items.first.author
        assert_equal Date.new(2024, 1, 10), result.items.first.published_on
        assert_equal BigDecimal("18000"), result.items.first.price_sales
        assert_includes requested_uri.query, "ttbkey=test-key"
        assert_includes requested_uri.query, "Query=Atomic+Habits"
      end

      test "returns graceful error when api responds with failure" do
        result = BookSearch.call(
          query: "Atomic Habits",
          ttb_key: "test-key",
          http_get: ->(*) { OpenStruct.new(code: "500", body: "server error") }
        )

        assert result.enabled?
        assert_empty result.items
        assert_match "HTTP 500", result.error_message
      end
    end
  end
end
