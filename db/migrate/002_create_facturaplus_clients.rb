class CreateFacturaplusClients < ActiveRecord::Migration
  def self.up
    create_table :facturaplus_clients, :force => true do |t|
      t.column :client_name, :string, :null => false
      t.column :biller_id, :integer, :null => true
      t.column :client_id, :integer, :null => true
    end
  end

  def self.down
    drop_table :facturaplus_clients
  end
end