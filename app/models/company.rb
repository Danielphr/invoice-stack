class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  # Invoices are declared before clients so they are destroyed first.
  # A client that still has invoices cannot be destroyed.
  has_many :invoices, dependent: :destroy
  has_many :clients, dependent: :destroy

  validates :name, presence: true, on: :update

  def onboarding_complete?
    name.present?
  end
end
