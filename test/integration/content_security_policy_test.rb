require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "only allows the app's own scripts and styles, with a nonce for the import map" do
    get new_session_url

    policy = response.headers["Content-Security-Policy"]
    assert_match "default-src 'self'", policy
    assert_match "object-src 'none'", policy
    assert_match "frame-ancestors 'none'", policy
    assert_match(/script-src 'self' 'nonce-[^']+'/, policy)

    nonce = policy[/'nonce-([^']+)'/, 1]
    assert_select "script[type=importmap][nonce=?]", nonce
  end
end
