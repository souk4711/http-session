require "webmock"

class HTTP::Session
  class WebMockPerform < HTTP::WebMockPerform
    def replay
      webmock_response = response_for_request request_signature
      return unless webmock_response

      raise_timeout_error if webmock_response.should_timeout
      webmock_response.raise_error_if_any

      invoke_callbacks(webmock_response, real_request: false)
      response = HTTP::Response.from_webmock @request, webmock_response, request_signature
      HTTP::Session::Response.new(response)
    end
  end

  class Client
    alias_method :__perform__, :httprb_perform

    def httprb_perform(request, options)
      return __perform__(request, options) unless webmock_enabled?
      HTTP::Session::WebMockPerform.new(request, options) { __perform__(request, options) }.exec
    end

    def webmock_enabled?
      WebMock::HttpLibAdapters::HttpRbAdapter.enabled?
    end
  end
end
