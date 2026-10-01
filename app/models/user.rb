class User < ApplicationRecord
  belongs_to :company

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :first_name, :last_name, presence: true
  validates :email_address, presence: true, uniqueness: true
end
