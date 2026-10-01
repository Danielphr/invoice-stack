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

    assert_equal [ "acme labs", "Globex Corporation", "Initech" ], css_select("tbody tr td:first-child").map { it.text.strip }
  end

  test "should show an empty state when there are no clients" do
    @user.company.clients.destroy_all

    get clients_url

    assert_select "table", count: 0
    assert_select "h2", "No clients yet"
  end

  test "should show a client" do
    get client_url(@client)

    assert_response :success
    assert_select "h1", @client.name
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
      delete client_url(@client)
    end

    assert_redirected_to clients_url
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
