class AddIrisCodeToFacturaplusClients < ActiveRecord::Migration
  def self.up
    add_column :facturaplus_clients, :iris_code, :string, :null => true
  end

  def self.down
    remove_column :facturaplus_clients, :iris_code
  end
end