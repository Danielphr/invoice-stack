require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

  # The default 2 seconds is tight on slower CI machines, or right after assets were recompiled.
  Capybara.default_max_wait_time = 5

  # The page's JavaScript loads a moment after its HTML, so clicking straight away can beat Stimulus
  # to it. Waiting until every controller on the page is connected keeps the tests from flaking.
  def visit(...)
    super
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "Stimulus controllers didn't connect" unless evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("[data-controller]")).every(element =>
          element.dataset.controller.split(/\s+/).every(identifier =>
            window.Stimulus?.getControllerForElementAndIdentifier(element, identifier)))
      JS
    end
  end

  private
    def sign_in_as(user)
      visit new_session_path
      fill_in "Email address", with: user.email_address
      fill_in "Password", with: "password"
      click_on "Sign in"
      assert_current_path root_path
    end
end
