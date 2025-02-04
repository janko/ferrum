# frozen_string_literal: true

require "concurrent-ruby"
require "ferrum/browser/subscriber"
require "ferrum/browser/web_socket"

module Ferrum
  class Browser
    class Client
      def initialize(browser, ws_url, start_id = 0, allow_slowmo = true)
        @command_id = start_id
        @pendings = Concurrent::Hash.new
        @browser = browser
        @slowmo = @browser.slowmo if allow_slowmo && @browser.slowmo > 0
        @ws = WebSocket.new(ws_url, @browser.logger)
        @subscriber = Subscriber.new

        @thread = Thread.new do
          while message = @ws.messages.pop
            if message.key?("method")
              @subscriber.async.call(message)
            else
              @pendings[message["id"]]&.set(message)
            end
          end
        end
      end

      def command(method, params = {})
        pending = Concurrent::IVar.new
        message = build_message(method, params)
        @pendings[message[:id]] = pending
        sleep(@slowmo) if @slowmo
        @ws.send_message(message)
        data = pending.value!(@browser.timeout)
        @pendings.delete(message[:id])

        raise DeadBrowserError if data.nil? && @ws.messages.closed?
        raise TimeoutError unless data
        error, response = data.values_at("error", "result")
        raise_browser_error(error) if error
        response
      end

      def on(event, &block)
        @subscriber.on(event, &block)
      end

      def close
        @ws.close
        # Give a thread some time to handle a tail of messages
        @pendings.clear
        Timeout.timeout(1) { @thread.join }
      rescue Timeout::Error
        @thread.kill
      end

      private

      def build_message(method, params)
        { method: method, params: params }.merge(id: next_command_id)
      end

      def next_command_id
        @command_id += 1
      end

      def raise_browser_error(error)
        case error["message"]
        # Node has disappeared while we were trying to get it
        when "No node with given id found",
             "Could not find node with given id"
          raise NodeNotFoundError.new(error)
        # Context is lost, page is reloading
        when "Cannot find context with specified id"
          raise NoExecutionContextError.new(error)
        when "No target with given id found"
          raise NoSuchWindowError
        else
          raise BrowserError.new(error)
        end
      end
    end
  end
end
