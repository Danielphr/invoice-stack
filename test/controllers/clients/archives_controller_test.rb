require "test_helper"

class Clients::ArchivesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @client = clients(:globex)
    sign_in_as users(:one)
  end

  test "should require authentication" do
    sign_out

    post client_archive_url(@client)

    assert_redirected_to new_session_url
    assert_nil @client.reload.archived_at
  end

  test "should archive a client" do
    post client_archive_url(@client)

    assert_redirected_to client_url(@client)
    assert @client.reload.archived?
  end

  test "should show why a client can't be archived" do
    @client.update_column(:website, "not a web address")

    post client_archive_url(@client)

    assert_redirected_to client_url(@client)
    assert_equal "Website is invalid", flash[:alert]
    assert_not @client.reload.archived?
  end

  test "should unarchive a client" do
    @client.archive

    delete client_archive_url(@client)

    assert_redirected_to client_url(@client)
    assert_not @client.reload.archived?
  end

  test "should not archive another company's client" do
    other_client = clients(:other_company_client)

    post client_archive_url(other_client)

    assert_response :not_found
    assert_not other_client.reload.archived?
  end
end
