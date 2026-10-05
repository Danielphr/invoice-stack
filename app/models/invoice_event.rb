class InvoiceEvent < ApplicationRecord
  ACTIONS = %w[ created status_changed edited archived unarchived ].freeze

  belongs_to :invoice
  # Empty for changes made outside a request, such as the demo seeds.
  belongs_to :user, optional: true

  validates :action, inclusion: { in: ACTIONS }

  # History is never rewritten.
  def readonly?
    persisted?
  end
end
