require "test_helper"

class CompaniesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = @user.company
    sign_in_as @user
  end

  test "should require authentication" do
    sign_out

    get company_url

    assert_redirected_to new_session_url
  end

  test "should show the company's details with a link to edit them" do
    @company.update!(email: "billing@acme.example", invoice_number_pattern: "YP-{NUMBER}", invoice_number_digits: 4,
      next_invoice_number: 42)

    get company_url

    assert_response :success
    assert_select "h1", "Acme Inc."
    assert_select "dd", "billing@acme.example"
    assert_select "dd", "YP-0042"
    assert_select "a[href=?]", edit_company_path, "Edit"
    assert_select "form[action=?]", company_path, count: 0
    assert_select "nav a[aria-current=page]", "Company"
  end

  test "should edit the company in a form with the logo drop zone" do
    @company.update!(invoice_number_pattern: "YP-{NUMBER}", invoice_number_digits: 4, next_invoice_number: 42)

    get edit_company_url

    assert_response :success
    assert_select "input[name=?][value=?]", "company[name]", "Acme Inc."
    assert_select "input[name=?][value=?]", "company[invoice_number_pattern]", "YP-{NUMBER}"
    assert_select "[data-controller=dropzone] input[type=file][name=?]", "company[logo]"
    assert_select "input[name=?][min='2']", "company[next_invoice_number]"
    assert_select "p", "Numbers below 2 are already used."
    assert_select "p", /Next invoice will be YP-0042/
    assert_select "nav a[aria-current=page]", "Company"
  end

  test "should update the company's details, address and preferences" do
    patch company_url, params: { company: {
      name: "Acme Studio", email: "billing@acme.example",
      address_line1: "Av. 18 de Julio 1234", city: "Montevideo", postal_code: "11100", country: "UY",
      time_zone: "Montevideo", default_currency: "UYU"
    } }

    assert_redirected_to company_url
    @company.reload
    assert_equal "Acme Studio", @company.name
    assert_equal "billing@acme.example", @company.email
    assert_equal [ "Av. 18 de Julio 1234", "Montevideo, 11100", "Uruguay" ], @company.address_lines
    assert_equal "Montevideo", @company.time_zone
    assert_equal "UYU", @company.default_currency
  end

  test "should remind the user to add an address until it is complete" do
    get company_url
    assert_select "[role=note]", /Add your company's address/

    @company.update!(address_line1: "100 Example Street", city: "Springfield", country: "US")
    get company_url
    assert_select "[role=note]", count: 0
  end

  test "should update and show the accent color" do
    patch company_url, params: { company: { accent_color: "#4F46E5" } }
    assert_equal "#4f46e5", @company.reload.accent_color

    get company_url
    assert_select "dd code", "#4f46e5"

    get edit_company_url
    assert_select "input[type=color][name=?][value=?]", "company[accent_color]", "#4f46e5"
  end

  test "should upload and show the logo" do
    patch company_url, params: { company: { logo: fixture_file_upload("logo.png", "image/png") } }
    assert_redirected_to company_url
    assert @company.reload.logo.attached?

    get company_url
    assert_select "img[alt=?]", "Acme Inc. logo"
  end

  test "should offer to remove the logo only when there is one" do
    get edit_company_url
    assert_select "button[form=remove-logo]", count: 0

    @company.logo.attach(io: file_fixture("logo.png").open, filename: "logo.png")
    get edit_company_url
    assert_select "button[form=remove-logo]"
    assert_select "form#remove-logo[action=?][data-turbo-confirm][data-confirm-destructive=true]", company_logo_path
  end

  test "should remove the logo" do
    @company.logo.attach(io: file_fixture("logo.png").open, filename: "logo.png")

    delete company_logo_url

    assert_redirected_to edit_company_url
    assert_not @company.reload.logo.attached?
  end

  test "should reject an unsupported logo and keep the current one" do
    @company.logo.attach(io: file_fixture("logo.png").open, filename: "logo.png")

    patch company_url, params: { company: { logo: fixture_file_upload("logo.svg", "image/svg+xml") } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Logo must be a PNG, JPG or WebP image"
    assert_equal "logo.png", @company.reload.logo.filename.to_s
  end

  test "should show the edit form again when the name is invalid" do
    patch company_url, params: { company: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "h1", "Edit company"
    assert_select "[role=alert] li", "Company name can't be blank"
  end

  test "should update the invoice number settings" do
    patch company_url, params: { company: {
      invoice_number_pattern: "YP-{YEAR}-{NUMBER}", invoice_number_digits: "3", next_invoice_number: "413"
    } }

    assert_redirected_to company_url
    @company.reload
    assert_equal "YP-{YEAR}-{NUMBER}", @company.invoice_number_pattern
    assert_equal 3, @company.invoice_number_digits
    assert_equal 413, @company.next_invoice_number
  end

  test "should show errors for an invalid pattern" do
    patch company_url, params: { company: { invoice_number_pattern: "INV-{YEAR}" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Number pattern must contain {NUMBER} exactly once"
    assert_equal "INV-{NUMBER}", @company.reload.invoice_number_pattern
  end

  test "should reject a next number too large to store" do
    patch company_url, params: { company: { next_invoice_number: "9999999999" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Next number must be less than 1000000000"
  end

  test "should only change the current user's company" do
    other_company = companies(:other)

    patch company_url, params: { company: { invoice_number_pattern: "MINE-{NUMBER}" } }

    assert_equal "INV-{NUMBER}", other_company.reload.invoice_number_pattern
  end
end
