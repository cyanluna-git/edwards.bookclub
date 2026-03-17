require "json"
require "net/http"
require "uri"

module Integrations
  module Aladin
    class BookSearch
      ENDPOINT = URI("https://www.aladin.co.kr/ttb/api/ItemSearch.aspx").freeze
      DEFAULT_MAX_RESULTS = 8
      API_VERSION = "20131101".freeze

      Item = Struct.new(
        :title,
        :author,
        :publisher,
        :cover_url,
        :link_url,
        :isbn13,
        :published_on,
        :price_sales,
        keyword_init: true
      ) do
        def prefill_attributes
          {
            title:,
            author:,
            publisher:,
            price: price_sales&.to_s("F"),
            cover_url:,
            link_url:
          }.compact
        end
      end

      Result = Struct.new(:enabled, :query, :items, :error_message, keyword_init: true) do
        def enabled?
          enabled
        end
      end

      def self.call(...)
        new(...).call
      end

      def initialize(query:, ttb_key: ENV["ALADIN_TTB_KEY"], http_get: Net::HTTP.method(:get_response))
        @query = query.to_s.strip
        @ttb_key = ttb_key.to_s.strip
        @http_get = http_get
      end

      def call
        return disabled_result if @ttb_key.blank?
        return Result.new(enabled: true, query: @query, items: [], error_message: nil) if @query.blank?

        response = @http_get.call(request_uri)
        return error_result("Aladin search failed with HTTP #{response.code}.") unless success_response?(response)

        payload = JSON.parse(response.body)
        return error_result(payload["errorMessage"] || "Aladin search failed.") if payload["errorCode"].present?

        Result.new(
          enabled: true,
          query: @query,
          items: Array(payload["item"]).map { |item| build_item(item) },
          error_message: nil
        )
      rescue JSON::ParserError
        error_result("Aladin search returned an unreadable response.")
      rescue StandardError
        error_result("Aladin search is temporarily unavailable.")
      end

      private

      def disabled_result
        Result.new(
          enabled: false,
          query: @query,
          items: [],
          error_message: "Configure ALADIN_TTB_KEY to enable Aladin search."
        )
      end

      def error_result(message)
        Result.new(enabled: true, query: @query, items: [], error_message: message)
      end

      def success_response?(response)
        response.code.to_i.between?(200, 299)
      end

      def request_uri
        uri = ENDPOINT.dup
        uri.query = URI.encode_www_form(
          ttbkey: @ttb_key,
          Query: @query,
          QueryType: "Keyword",
          SearchTarget: "Book",
          MaxResults: DEFAULT_MAX_RESULTS,
          start: 1,
          output: "js",
          Version: API_VERSION,
          Cover: "Big"
        )
        uri
      end

      def build_item(item)
        Item.new(
          title: item["title"].to_s.strip,
          author: item["author"].to_s.strip.presence,
          publisher: item["publisher"].to_s.strip.presence,
          cover_url: item["cover"].to_s.strip.presence,
          link_url: item["link"].to_s.strip.presence,
          isbn13: item["isbn13"].to_s.strip.presence,
          published_on: parse_date(item["pubDate"]),
          price_sales: parse_decimal(item["priceSales"])
        )
      end

      def parse_date(value)
        return if value.blank?

        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def parse_decimal(value)
        return if value.blank?

        BigDecimal(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
