# frozen_string_literal: true

require "spec_helper"

module Ferrum
  describe "Browser::API::Input" do
    let!(:browser) { Browser.new(base_url: @server.base_url) }

    after { browser.reset }

    context "has ability to send keys" do
      before { browser.goto("/ferrum/type") }

      it "sends keys to empty input" do
        input = browser.at_css("#empty_input")
        input.focus.type("Input")

        expect(input.value).to eq("Input")
      end

      it "sends keys to filled input" do
        input = browser.at_css("#filled_input")

        input.click.type(" appended")

        expect(input.value).to eq("Text appended")
      end

      it "sends keys to empty textarea" do
        input = browser.at_css("#empty_textarea")

        input.focus.type("Input")

        expect(input.value).to eq("Input")
      end

      it "sends keys to filled textarea" do
        input = browser.at_css("#filled_textarea")

        input.click.type(" appended")

        expect(input.value).to eq("Description appended")
      end

      it "sends keys to empty contenteditable div" do
        input = browser.at_css("#empty_div")

        input.click.type("Input")

        expect(input.text).to eq("Input")
      end

      it "persists focus across calls" do
        input = browser.at_css("#empty_div")

        input
          .focus
          .type("helo")
          .type(:Left)
          .type("l")

        expect(input.text).to eq("hello")
      end

      it "sends keys to filled contenteditable div" do
        input = browser.at_css("#filled_div")

        input.click.type(" appended")

        expect(input.text).to eq("Content appended")
      end

      it "sends sequences" do
        input = browser.at_css("#empty_input")

        input.focus.type([:Shift], "S", [:Alt], "t", "r", "i", "g", :Left, "n")

        expect(input.value).to eq("String")
      end

      it "submits the form with sequence" do
        input = browser.at_css("#without_submit_button input")

        input.focus.type(:Enter)

        expect(input.value).to eq("Submitted")
      end

      it "sends sequences with modifiers and letters" do
        input = browser.at_css("#empty_input")

        input.focus.type([:Shift, "s"], "t", "r", "i", "n", "g")

        expect(input.value).to eq("String")
      end

      it "sends sequences with modifiers and symbols" do
        input = browser.at_css("#empty_input")

        keys = Ferrum.mac? ? %i[Alt Left] : %i[Ctrl Left]

        input.focus.type("t", "r", "i", "n", "g", keys, "s")

        expect(input.value).to eq("string")
      end

      it "sends sequences with multiple modifiers and symbols" do
        input = browser.at_css("#empty_input")

        keys = Ferrum.mac? ? %i[Alt Shift Left] : %i[Ctrl Shift Left]

        input.focus.type("t", "r", "i", "n", "g", keys, "s")

        expect(input.value).to eq("s")
      end

      it "sends modifiers with sequences" do
        input = browser.at_css("#empty_input")

        input.focus.type("s", [:Shift, "tring"])

        expect(input.value).to eq("sTRING")
      end

      it "sends modifiers with multiple keys" do
        input = browser.at_css("#empty_input")

        input.focus.type("helo", %i[Shift Left Left], "llo")

        expect(input.value).to eq("hello")
      end

      it "generates correct events with keyCodes for modified puncation" do
        input = browser.at_css("#empty_input")

        input.focus.type([:shift, "."], [:shift, "t"])

        expect(browser.at_css("#key-events-output").text.strip).to eq("keydown:16 keydown:190 keydown:16 keydown:84")
      end

      it "suuports snake_case sepcified keys (Capybara standard)" do
        input = browser.at_css("#empty_input")
        input.focus.type(:PageUp, :page_up)
        expect(browser.at_css("#key-events-output").text.strip).to eq("keydown:33 keydown:33")
      end

      it "supports :control alias for :Ctrl" do
        input = browser.at_css("#empty_input")
        input.focus.type([:Ctrl, "a"], [:control, "a"])
        expect(browser.at_css("#key-events-output").text.strip).to eq("keydown:17 keydown:65 keydown:17 keydown:65")
      end

      it "supports :command alias for :Meta" do
        input = browser.at_css("#empty_input")
        input.focus.type([:Meta, "z"], [:command, "z"])
        expect(browser.at_css("#key-events-output").text.strip).to eq("keydown:91 keydown:90 keydown:91 keydown:90")
      end

      it "supports Capybara specified numpad keys" do
        input = browser.at_css("#empty_input")
        input.focus.type(:numpad2, :numpad8, :divide, :decimal)
        expect(browser.at_css("#key-events-output").text.strip).to eq("keydown:98 keydown:104 keydown:111 keydown:110")
      end

      it "raises error for unknown keys" do
        input = browser.at_css("#empty_input")
        expect do
          input.focus.type("abc", :blah)
        end.to raise_error KeyError, "key not found: :blah"
      end
    end

    context "set" do
      before { browser.goto("/ferrum/set") }

      it "sets contenteditable's content" do
        input = browser.at_css("#filled_div")
        input.focus.type([:Ctrl, "A"], :Backspace, "new text")
        expect(input.text).to eq("new text")
      end

      it "sets multiple contenteditables' content" do
        input = browser.at_css("#empty_div")
        input.focus.type("new text")

        expect(input.text).to eq("new text")

        input = browser.at_css("#filled_div")
        input.focus.type([:Ctrl, "A"], :Backspace, "replacement text")

        expect(input.text).to eq("replacement text")
      end

      it "sets a content editable childs content" do
        browser.goto("/orig_with_js")
        input = browser.at_css("#existing_content_editable_child")
        input.click.type(" WYSIWYG")
        expect(input.text).to eq("Content WYSIWYG")
      end

      describe "events" do
        let(:input) { browser.at_css("#input") }
        let(:output) { browser.at_css("#output") }

        before { browser.goto("/ferrum/input_events") }

        it "calls event handlers in the correct order" do
          input.focus.type("a").blur
          expect(output.text.strip).to eq("keydown keypress input keyup change")
          expect(input.value).to eq("a")
        end

        it "respects preventDefault() calls in keydown handlers" do
          browser.execute "input.addEventListener('keydown', e => e.preventDefault())"
          input.focus.type("a")
          expect(output.text.strip).to eq("keydown keyup")
          expect(input.value).to be_empty
        end

        it "respects preventDefault() calls in keypress handlers" do
          browser.execute "input.addEventListener('keypress', e => e.preventDefault())"
          input.focus.type("a")
          expect(output.text.strip).to eq("keydown keypress keyup")
          expect(input.value).to be_empty
        end

        it "calls event handlers for each character input" do
          input.focus.type("abc").blur
          expect(output.text.strip).to eq((["keydown keypress input keyup"] * 3).join(" ") + " change")
          expect(input.value).to eq("abc")
        end

        it "doesn't call the change event if there is no change" do
          input.focus.type("a").blur
          input.focus.type("a")

          expect(output.text.strip).to eq("keydown keypress input keyup change keydown keypress input keyup")
        end
      end
    end

    context "date_fields" do
      before { browser.goto("/ferrum/date_fields") }

      it "sets a date" do
        input = browser.at_css("#date_field")

        input.focus.type("02-14-2016")

        expect(input.value).to eq("2016-02-14")
      end
    end
  end
end
