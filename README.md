# InvoiceStack

Invoicing for freelancers and small studios: clients, fixed-price and hourly invoices, PDF export and gap-free invoice numbering, with each company's data kept separate.

Built with Ruby on Rails 8.1, PostgreSQL, Hotwire and Tailwind CSS.

## Running locally

You need Ruby 4.0.7, PostgreSQL and libvips.

```sh
bin/setup
```

This installs the gems, creates the database with demo data and starts the app at http://localhost:3000. Sign in as `demo@example.com` with the password `password`.

To start over with fresh demo data:

```sh
bin/rails db:seed:replant
```

## Tests

```sh
bin/ci
```

Runs the style and security checks and the test suite.
