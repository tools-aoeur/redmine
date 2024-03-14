class AddQueriesSharing < ActiveRecord::Migration[4.2]
  def self.up
    add_column :queries, :sharing, :string, :default => 'none', :null => false
    add_index :queries, :sharing
  end

  def self.down
    remove_column :queries, :sharing
  end
end
