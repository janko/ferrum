# frozen_string_literal: true

module Ferrum
  class Page
    module Net
      RESOURCE_TYPES = %w[Document Stylesheet Image Media Font Script TextTrack
                          XHR Fetch EventSource WebSocket Manifest
                          SignedExchange Ping CSPViolationReport Other]

      def proxy_authorize(user, password)
        @proxy_authorized_ids ||= []

        if user && password
          intercept_request do |request, index, total|
            if request.auth_challenge?(:proxy)
              response = authorized_response(@proxy_authorized_ids,
                                             request.interception_id,
                                             user, password)
              @proxy_authorized_ids << request.interception_id
              request.continue(authChallengeResponse: response)
            elsif index + 1 < total
              next # There are other callbacks that can handle this, skip
            else
              request.continue
            end
          end
        end
      end

      def authorize(user, password)
        @authorized_ids ||= []

        intercept_request do |request, index, total|
          if request.auth_challenge?(:server)
            response = authorized_response(@authorized_ids,
                                           request.interception_id,
                                           user, password)

            @authorized_ids << request.interception_id
            request.continue(authChallengeResponse: response)
          elsif index + 1 < total
            next # There are other callbacks that can handle this, skip
          else
            request.continue
          end
        end
      end

      def intercept_request(pattern: "*", resource_type: nil, &block)
        pattern = { urlPattern: pattern }
        if resource_type && RESOURCE_TYPES.include?(resource_type.to_s)
          pattern[:resourceType] = resource_type
        end

        command("Network.setRequestInterception", patterns: [pattern])

        on_request_intercepted(&block) if block_given?
      end

      def on_request_intercepted(&block)
        @client.on("Network.requestIntercepted") do |params, index, total|
          request = Network::InterceptedRequest.new(self, params)
          block.call(request, index, total)
        end
      end

      def continue_request(interception_id, options = nil)
        options ||= {}
        options = options.merge(interceptionId: interception_id)
        command("Network.continueInterceptedRequest", **options)
      end

      def abort_request(interception_id)
        continue_request(interception_id, errorReason: "Aborted")
      end

      private

      def subscribe
        super if defined?(super)

        @client.on("Network.loadingFailed") do |params|
          # Free mutex as we aborted main request we are waiting for
          if params["requestId"] == @request_id && params["canceled"] == true
            @event.set
            @document_id = get_document_id
          end
        end
      end

      def authorized_response(ids, interception_id, username, password)
        if ids.include?(interception_id)
          { response: "CancelAuth" }
        elsif username && password
          { response: "ProvideCredentials",
            username: username,
            password: password }
        else
          { response: "CancelAuth" }
        end
      end
    end
  end
end
