require "test_helper"

class CloudflareAccessTest < ActiveSupport::TestCase
  TEAM_DOMAIN = "team.cloudflareaccess.com"
  AUDIENCE = "access-app-audience"

  setup do
    @key = signing_key("key-1")
    @published_keys = [ key_set(@key) ]
  end

  test "lets in requests signed by Cloudflare Access" do
    assert_equal 200, get(token: token).status
  end

  test "refuses requests without a token" do
    assert_equal 403, get.status
  end

  test "refuses tokens for another Access application" do
    assert_equal 403, get(token: token(aud: [ "another-app" ])).status
  end

  test "refuses tokens from another Cloudflare team" do
    assert_equal 403, get(token: token(iss: "https://another-team.cloudflareaccess.com")).status
  end

  test "refuses expired tokens" do
    assert_equal 403, get(token: token(exp: 1.minute.ago.to_i)).status
  end

  test "refuses tokens signed with a key that isn't Cloudflare's" do
    forged = token(key: signing_key(@key.kid))

    assert_equal 403, get(token: forged).status
  end

  test "refuses unsigned tokens" do
    unsigned = JWT.encode({ iss: "https://#{TEAM_DOMAIN}", aud: [ AUDIENCE ] }, nil, "none")

    assert_equal 403, get(token: unsigned).status
  end

  test "lets the health check through without a token" do
    assert_equal 200, get("/up").status
  end

  test "refuses everything when it isn't configured" do
    assert_equal 403, get(token: token, middleware: middleware(team_domain: nil)).status
    assert_equal 403, get(token: token, middleware: middleware(audience: "")).status
  end

  test "refuses requests when Cloudflare's keys can't be loaded" do
    @published_keys = [ SocketError.new("Failed to open TCP connection") ]

    assert_equal 403, get(token: token).status
  end

  test "loads Cloudflare's new keys after they rotate" do
    new_key = signing_key("key-2")
    @published_keys = [ key_set(@key), key_set(new_key) ]
    access = middleware

    assert_equal 200, get(token: token, middleware: access).status

    travel CloudflareAccess::KEYS_REFRESH_INTERVAL + 1.second do
      assert_equal 200, get(token: token(key: new_key), middleware: access).status
    end
  end

  test "doesn't reload keys more often than the refresh interval" do
    unknown_key = signing_key("key-2")
    @published_keys = [ key_set(@key), key_set(unknown_key) ]
    access = middleware

    assert_equal 200, get(token: token, middleware: access).status
    assert_equal 403, get(token: token(key: unknown_key), middleware: access).status
  end

  private
    def get(path = "/", token: nil, middleware: self.middleware)
      headers = token ? { CloudflareAccess::TOKEN_HEADER => token } : {}
      Rack::MockRequest.new(middleware).get(path, headers)
    end

    # Cloudflare's published keys are served from @published_keys, one set per fetch.
    def middleware(team_domain: TEAM_DOMAIN, audience: AUDIENCE)
      app = ->(env) { [ 200, {}, [ "OK" ] ] }
      published_keys = @published_keys.dup

      CloudflareAccess.new(app, team_domain:, audience:).tap do |access|
        access.define_singleton_method(:fetch_keys) do
          keys = published_keys.size > 1 ? published_keys.shift : published_keys.first
          keys.is_a?(Exception) ? raise(keys) : keys
        end
      end
    end

    def token(key: @key, iss: "https://#{TEAM_DOMAIN}", aud: [ AUDIENCE ], exp: 1.minute.from_now.to_i)
      JWT.encode({ iss:, aud:, exp:, email: "partner@example.com" }, key.signing_key, "RS256", kid: key.kid)
    end

    def signing_key(kid)
      JWT::JWK.new(OpenSSL::PKey::RSA.generate(2048), { kid: })
    end

    def key_set(key)
      JSON.parse(JWT::JWK::Set.new(key).export.to_json)
    end
end
