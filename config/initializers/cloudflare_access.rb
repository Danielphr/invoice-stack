# In production, only requests that came through Cloudflare Access reach the app.
# The team domain and audience tag come from the Access application's settings.
if Rails.env.production?
  Rails.application.config.middleware.use CloudflareAccess,
    team_domain: ENV["CLOUDFLARE_ACCESS_TEAM_DOMAIN"],
    audience: ENV["CLOUDFLARE_ACCESS_AUD"]
end
