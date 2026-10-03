# Demo data for local development. Sign in as demo@example.com / password.
# Reload from scratch with: bin/rails db:seed:replant

return if User.exists?(email_address: "demo@example.com")

ActiveRecord::Base.transaction do
  company = Company.create!(
    name: "Northwind Studio", email: "billing@northwind.example",
    address_line1: "1200 Market Street", city: "San Francisco", state: "California", postal_code: "94102", country: "US",
    time_zone: "Pacific Time (US & Canada)", default_currency: "USD", accent_color: "#4f46e5",
    invoice_number_pattern: "NW-{YEAR}-{NUMBER}", invoice_number_digits: 3
  )

  company.users.create!(first_name: "Demo", last_name: "User", email_address: "demo@example.com", password: "password")

  clients = [
    company.clients.create!(name: "Lumen Labs", email: "accounts@lumenlabs.example", city: "Austin", state: "Texas",
      country: "US", contact_first_name: "Maya", contact_last_name: "Chen"),
    company.clients.create!(name: "Harbor & Pine", email: "hello@harborandpine.example", city: "Portland", state: "Oregon",
      country: "US"),
    company.clients.create!(name: "Café Montaña", email: "pagos@cafemontana.example", city: "Montevideo", country: "UY"),
    company.clients.create!(name: "Brightline Logistics", email: "finance@brightline.example", city: "London", country: "GB")
  ]

  projects = [ "Brand identity", "Website redesign", "Landing page", "Design system audit", "Mobile app UI" ]
  services = [ "Design sprint", "Frontend development", "UX research", "Support and maintenance" ]
  random = Random.new(42)
  today = Time.find_zone(company.time_zone).today

  build_invoice = ->(index, issue_date, status) do
    client = clients[index % clients.size]
    currency = client.country == "UY" ? "UYU" : "USD"
    rate = currency == "UYU" ? 40 : 1
    invoice = company.invoices.new(client:, status:, currency:, issue_date:, due_date: issue_date + [ 15, 30 ].sample(random:),
      billing_type: index.odd? ? "hourly" : "fixed")

    if invoice.hourly?
      services.sample(random.rand(1..2), random:).each do |service|
        invoice.items.build(description: service, quantity: random.rand(4..40), unit_price: [ 75, 95, 120 ].sample(random:) * rate)
      end
    else
      invoice.items.build(description: projects.sample(random:), quantity: 1, unit_price: random.rand(16..120) * 50 * rate)
    end

    invoice
  end

  # Issued invoices, oldest first, so their numbers follow their dates.
  20.times do |index|
    issue_date = today - (240 - index * 12)
    status = if index % 7 == 3 then "cancelled" elsif issue_date < today - 60 then "paid" else "sent" end
    invoice = build_invoice.(index, issue_date, status)
    invoice.paid_on = [ issue_date + random.rand(5..25), today ].min if invoice.paid?
    invoice.save!
  end

  3.times { |index| build_invoice.(index, today - index, "draft").save! }
end
