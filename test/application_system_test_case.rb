require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

  # The default 2 seconds is tight on slower CI machines, or right after assets were recompiled.
  Capybara.default_max_wait_time = 5

  private
    def sign_in_as(user)
      visit new_session_path
      fill_in "Email address", with: user.email_address
      fill_in "Password", with: "password"
      click_on "Sign in"
      assert_current_path root_path
    end
end
