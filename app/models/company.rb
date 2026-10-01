class Company < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :clients, dependent: :destroy

  validates :name, presence: true, on: :update

  def onboarding_complete?
    name.present?
  end
end
