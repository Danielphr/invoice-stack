require "test_helper"

# Runs outside a test transaction so several threads, each with its own
# database connection, can create invoices for the same company at once.
class InvoiceNumberingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  THREADS = 4

  setup do
    @company = Company.create!(name: "Concurrent Co")
    @client = @company.clients.create!(name: "Client", city: "Montevideo", country: "UY")
  end

  teardown do
    @company.destroy!
  end

  test "invoices created at the same time get distinct numbers" do
    gate = Queue.new

    threads = THREADS.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          company = Company.find(@company.id)
          invoice = company.invoices.new(client_id: @client.id, currency: "USD", issue_date: Date.current)
          invoice.items.build(description: "Work", quantity: 1, unit_price: 100)

          gate.pop
          invoice.save!
          invoice.number
        end
      end
    end

    THREADS.times { gate << :go }
    numbers = threads.map(&:value)

    assert_equal (1..THREADS).map { "INV-#{it}" }, numbers.sort_by { it.delete_prefix("INV-").to_i }
    assert_equal THREADS + 1, @company.reload.next_invoice_number
  end
end
