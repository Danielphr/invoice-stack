# Deployment

Production is deployed with [Kamal](https://kamal-deploy.org). Server details and secrets are
never committed: they live in a private `.env.production` file, ignored by Git.

## Configuration

`.env.production` sets:

| Variable | What it is |
| --- | --- |
| `KAMAL_HOST` | The server's SSH host name |
| `KAMAL_SSH_USER` | The user Kamal connects as |
| `APP_HOST` | The app's host name |
| `INVOICE_STACK_DATABASE_PASSWORD` | The Postgres password |
| `CLOUDFLARE_ACCESS_TEAM_DOMAIN` | The Cloudflare Access team domain |
| `CLOUDFLARE_ACCESS_AUD` | The Cloudflare Access application's audience tag |

`config/master.key` must also be present.

## Commands

```sh
bundle exec dotenv -f .env.production bin/kamal setup   # first deploy
bundle exec dotenv -f .env.production bin/kamal deploy
```
