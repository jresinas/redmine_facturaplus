class AddCurrencyToFacturaplusRelations < ActiveRecord::Migration
  def self.up
    add_column :facturaplus_relations, :currency, :integer, :null => false
  end

  def self.down
    remove_column :facturaplus_relations, :currency
  end
end