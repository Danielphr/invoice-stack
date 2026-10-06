require "application_system_test_case"

class CompanyLogoTest < ApplicationSystemTestCase
  test "previews a chosen logo before saving it" do
    sign_in_as users(:one)
    visit edit_company_path
    assert_text "No logo"

    attach_file "company[logo]", file_fixture("logo.png"), make_visible: true

    assert_selector "img[alt='Logo preview'][src^='blob:']"
    assert_no_text "No logo"

    click_on "Save"
    assert_text "Company updated."
    assert_selector "img[alt='#{companies(:one).name} logo']"
  end
end
