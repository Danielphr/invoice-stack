ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Issued invoices can't be destroyed, so tests that need none skip the callbacks.
    def remove_invoices(company)
      InvoiceItem.where(invoice: company.invoices).delete_all
      company.invoices.delete_all
    end
  end
end
