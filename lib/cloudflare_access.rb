require "net/http"

# Answers only requests that came through Cloudflare Access, so the app can't be reached
# by going around it. Cloudflare signs every request it lets in with a JWT, which is
# checked against the team's public keys and the Access application's audience tag.
class CloudflareAccess
  TOKEN_HEADER = "HTTP_CF_ACCESS_JWT_ASSERTION"
  # The health check is called from inside the server, never through Cloudflare.
  HEALTH_CHECK_PATH = "/up"
  KEYS_REFRESH_INTERVAL = 5.minutes

  def initialize(app, team_domain:, audience:)
    @app = app
    @issuer = "https://#{team_domain}" if team_domain.present?
    @audience = audience.presence
    @mutex = Mutex.new
  end

  def call(env)
    if env["PATH_INFO"] == HEALTH_CHECK_PATH || authorized?(env[TOKEN_HEADER])
      @app.call(env)
    else
      [ 403, { "content-type" => "text/plain" }, [ "Forbidden" ] ]
    end
  end

  private
    def authorized?(token)
      if @issuer.nil? || @audience.nil?
        Rails.logger.error("Cloudflare Access isn't configured, so every request is refused.")
        return false
      end
      return false if token.blank?

      JWT.decode(token, nil, true, algorithms: [ "RS256" ], jwks: method(:keys),
        iss: @issuer, verify_iss: true, aud: @audience, verify_aud: true)
      true
    rescue JWT::DecodeError => error
      Rails.logger.warn("Cloudflare Access token refused: #{error.message}")
      false
    end

    # JWT.decode asks again with kid_not_found when Cloudflare has rotated its keys.
    # Refreshing at most every few minutes keeps forged key ids from flooding Cloudflare.
    def keys(options)
      @mutex.synchronize do
        @keys = nil if options[:kid_not_found] && @keys_fetched_at.before?(KEYS_REFRESH_INTERVAL.ago)
        @keys ||= JWT::JWK::Set.new(fetch_keys).tap { @keys_fetched_at = Time.current }
      end
    rescue StandardError => error
      raise JWT::JWKError, "Cloudflare's keys couldn't be loaded: #{error.message}"
    end

    def fetch_keys
      uri = URI("#{@issuer}/cdn-cgi/access/certs")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
        http.get(uri.path)
      end
      response.value
      JSON.parse(response.body)
    end
end
