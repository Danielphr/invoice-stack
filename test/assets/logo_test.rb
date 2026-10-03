require "test_helper"

class LogoTest < ActiveSupport::TestCase
  # The error pages are static and can't use fingerprinted assets, so they link to a copy in public/.
  test "the error pages' logo matches the app's logo" do
    assert FileUtils.identical?(Rails.root.join("public/logo.svg"), Rails.root.join("app/assets/images/logo.svg")),
      "public/logo.svg is out of date; copy app/assets/images/logo.svg over it"
  end
end
