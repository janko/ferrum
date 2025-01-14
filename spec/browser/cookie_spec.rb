# frozen_string_literal: true

require "spec_helper"

module Ferrum
  describe "cookies support" do
    let!(:browser) { Browser.new(base_url: @server.base_url) }

    after { browser.reset }

    it "returns set cookies" do
      browser.goto("/set_cookie")

      cookie = browser.cookies["stealth"]
      expect(cookie.name).to eq("stealth")
      expect(cookie.value).to eq("test_cookie")
      expect(cookie.domain).to eq("127.0.0.1")
      expect(cookie.path).to eq("/")
      expect(cookie.size).to eq(18)
      expect(cookie.secure?).to be false
      expect(cookie.httponly?).to be false
      expect(cookie.session?).to be true
      expect(cookie.expires).to be_nil
    end

    it "can set cookies" do
      browser.cookies.set(name: "stealth", value: "omg")
      browser.goto("/get_cookie")
      expect(browser.body).to include("omg")
    end

    it "can set cookies with custom settings" do
      browser.cookies.set(name: "stealth", value: "omg", path: "/ferrum")

      browser.goto("/get_cookie")
      expect(browser.body).to_not include("omg")

      browser.goto("/ferrum/get_cookie")
      expect(browser.body).to include("omg")

      expect(browser.cookies["stealth"].path).to eq("/ferrum")
    end

    it "can remove a cookie" do
      browser.goto("/set_cookie")

      browser.goto("/get_cookie")
      expect(browser.body).to include("test_cookie")

      browser.cookies.remove(name: "stealth")

      browser.goto("/get_cookie")
      expect(browser.body).to_not include("test_cookie")
    end

    it "can clear cookies" do
      browser.goto("/set_cookie")

      browser.goto("/get_cookie")
      expect(browser.body).to include("test_cookie")

      browser.cookies.clear

      browser.goto("/get_cookie")
      expect(browser.body).to_not include("test_cookie")
    end

    it "can set cookies with an expires time" do
      time = Time.at(Time.now.to_i + 10000)
      browser.goto
      browser.cookies.set(name: "foo", value: "bar", expires: time)
      expect(browser.cookies["foo"].expires).to eq(time)
    end

    it "can set cookies for given domain" do
      port = @server.port
      browser.cookies.set(name: "stealth", value: "127.0.0.1")
      browser.cookies.set(name: "stealth", value: "localhost", domain: "localhost")

      browser.goto("http://localhost:#{port}/ferrum/get_cookie")
      expect(browser.body).to include("localhost")

      browser.goto("http://127.0.0.1:#{port}/ferrum/get_cookie")
      expect(browser.body).to include("127.0.0.1")
    end

    it "sets cookies correctly with :domain option when base_url isn't set" do
      begin
        browser = Browser.new
        browser.cookies.set(name: "stealth", value: "123456", domain: "localhost")

        port = @server.port
        browser.goto("http://localhost:#{port}/ferrum/get_cookie")
        expect(browser.body).to include("123456")

        browser.goto("http://127.0.0.1:#{port}/ferrum/get_cookie")
        expect(browser.body).not_to include("123456")
      ensure
        browser&.quit
      end
    end
  end
end
