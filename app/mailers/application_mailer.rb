class ApplicationMailer < ActionMailer::Base
  # In production, MAIL_FROM is an address on the app's own domain, which Resend has verified.
  default from: ENV.fetch("MAIL_FROM", "InvoiceStack <no-reply@example.com>")
  layout "mailer"
end
