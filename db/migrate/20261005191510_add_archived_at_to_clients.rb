class AddArchivedAtToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :archived_at, :datetime
  end
end
