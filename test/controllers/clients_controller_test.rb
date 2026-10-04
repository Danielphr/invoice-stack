require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @client = clients(:globex)
    @other_client = clients(:other_company_client)
    sign_in_as @user
  end

  test "should require authentication" do
    sign_out

    get clients_url

    assert_redirected_to new_session_url
  end

  test "should list only the company's clients, ordered by name" do
    get clients_url

    assert_response :success
    assert_select "tbody tr", 2
    assert_select "tbody tr:first-child", /Globex Corporation/
    assert_select "tbody tr:last-child", /Initech/
    assert_select "tbody", text: /Wayne Enterprises/, count: 0
  end

  test "should order clients by name regardless of case" do
    @user.company.clients.create!(name: "acme labs", city: "Austin", country: "US")

    get clients_url

    assert_equal [ "acme labs", "Globex Corporation", "Initech" ], css_select("tbody tr td:first-child a").map { it.text.strip }
  end

  test "should show each client's invoice count, amount outstanding and overdue invoices" do
    travel_to Date.new(2026, 10, 15) do
      get clients_url
    end

    assert_select "p", "2 clients"
    assert_select "tbody tr", text: /GC\s+Globex Corporation\s+billing@globex.example\s+Springfield, United States\s+2\s+\$2,150.00 USD\s+1 overdue/
    assert_select "tbody tr", text: /Initech\s+—\s+Montevideo, Uruguay\s+0\s+—/
    assert_select "tbody tr a[href=?]", client_path(@client), "Globex Corporation"
    assert_select "tbody tr a[href=?]", "mailto:billing@globex.example"
  end

  test "should offer edit for every client and delete only for clients without invoices" do
    get clients_url

    assert_select "tbody a[href=?]", edit_client_path(@client), /Edit/
    assert_select "tbody a[href=?]", edit_client_path(clients(:initech)), /Edit/
    assert_select "tbody form[action=?]", client_path(@client), count: 0
    assert_select "tbody form[action=?][data-confirm-destructive=true] button", client_path(clients(:initech)), /Delete/
  end

  test "should sort clients by invoice count and link to the opposite direction" do
    get clients_url(sort: "invoices", direction: "desc")

    assert_equal [ "Globex Corporation", "Initech" ], css_select("tbody tr td:first-child a").map { it.text.strip }
    assert_select "th[aria-sort=descending]", /Invoices/
    assert_select "th a[href=?]", clients_path(sort: "invoices", direction: "asc")
  end

  test "should paginate clients, ten per page" do
    11.times { |index| @user.company.clients.create!(name: "Client #{index.to_s.rjust(2, "0")}", city: "Austin", country: "US") }

    get clients_url

    assert_select "p", "13 clients"
    assert_select "tbody tr", 10
    assert_select "nav.pagy a[rel=next]"

    get clients_url(page: 9)
    assert_redirected_to clients_url(page: 2)
  end

  test "should show an empty state when there are no clients" do
    remove_invoices(@user.company)
    @user.company.clients.destroy_all

    get clients_url

    assert_select "table", count: 0
    assert_select "h2", "No clients yet"
  end

  test "should show a client with their totals and invoices" do
    travel_to Date.new(2026, 10, 15) do
      get client_url(@client)
    end

    assert_response :success
    assert_select "h1", @client.name
    assert_select "a[href=?]", "mailto:billing@globex.example"
    assert_select "a[href=?][target=_blank]", "https://globex.example", "globex.example"
    assert_select "dl > div", text: /Billed\s+\$2,150.00 USD\s+1 invoice issued/
    assert_select "dl > div", text: /Paid\s+No payments yet/
    assert_select "dl > div", text: /Outstanding\s+\$2,150.00 USD\s+1 awaiting payment/
    assert_select "dl > div", text: /Overdue\s+\$2,150.00 USD\s+1 past due/
    assert_select "#client-invoices-heading", /Invoices\s+· 2/
    assert_select "section[aria-labelledby=client-invoices-heading] tbody tr", 2
    assert_select "section[aria-labelledby=client-invoices-heading] tbody a[href=?]", invoice_path(invoices(:globex_website)), "INV-001"
    assert_select "a[href=?]", new_invoice_path(client_id: @client.id), "New invoice"
    assert_select "form[action=?]", client_path(@client), count: 0
  end

  test "should offer to delete a client without invoices" do
    client = clients(:initech)

    get client_url(client)

    assert_select "p", "No invoices yet for this client."
    assert_select "form[action=?][data-turbo-confirm][data-confirm-title=?][data-confirm-destructive=true]", client_path(client), "Delete client"
  end

  test "should highlight Clients in the navigation on client pages" do
    [ clients_url, client_url(@client), edit_client_url(@client) ].each do |url|
      get url

      assert_select "nav a[aria-current=page]", "Clients"
    end
  end

  test "should get new" do
    get new_client_url

    assert_response :success
    assert_select "form[autocomplete=off]"
  end

  test "should create a client for the current company" do
    assert_difference -> { @user.company.clients.count }, 1 do
      post clients_url, params: {
        client: { name: "Hooli", city: "Palo Alto", country: "US", company_id: companies(:other).id }
      }
    end

    client = Client.order(:created_at).last
    assert_equal @user.company, client.company
    assert_redirected_to client_url(client)
  end

  test "should not create an invalid client" do
    assert_no_difference "Client.count" do
      post clients_url, params: { client: { name: "", city: "", country: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Name can't be blank"
  end

  test "should update a client" do
    patch client_url(@client), params: { client: { name: "Globex Inc." } }

    assert_redirected_to client_url(@client)
    assert_equal "Globex Inc.", @client.reload.name
  end

  test "should not update a client with invalid data" do
    patch client_url(@client), params: { client: { phone: "not a phone" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Phone is invalid"
  end

  test "should destroy a client" do
    assert_difference "Client.count", -1 do
      delete client_url(clients(:initech))
    end

    assert_redirected_to clients_url
  end

  test "should not destroy a client that has invoices" do
    assert_no_difference "Client.count" do
      delete client_url(@client)
    end

    assert_redirected_to client_url(@client)
    follow_redirect!
    assert_select "[role=alert]", /has invoices and can't be deleted/
  end

  test "should not expose another company's client" do
    get client_url(@other_client)
    assert_response :not_found

    get edit_client_url(@other_client)
    assert_response :not_found
  end

  test "should not change another company's client" do
    patch client_url(@other_client), params: { client: { name: "Hacked" } }
    assert_response :not_found

    assert_no_difference "Client.count" do
      delete client_url(@other_client)
    end
    assert_response :not_found

    assert_equal "Wayne Enterprises", @other_client.reload.name
  end
end
