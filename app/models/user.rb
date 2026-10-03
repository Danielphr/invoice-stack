class User < ApplicationRecord
  PASSWORD_MIN_LENGTH = 12

  belongs_to :company

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :first_name, :last_name, presence: true, length: { maximum: 100 }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP },
    length: { maximum: 254 }
  # Only checked when a password is set, so existing passwords keep working.
  validates :password, length: { minimum: PASSWORD_MIN_LENGTH }, allow_nil: true
end
