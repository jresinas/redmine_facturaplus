class AddVatAndCurrencyExchangeToFacturaplusRelations < ActiveRecord::Migration
  def self.up
    add_column :facturaplus_relations, :vat, :string, :null => false
    add_column :facturaplus_relations, :currency_exchange, :decimal, :null => false
  end

  def self.down
    remove_column :facturaplus_relations, :vat
    remove_column :facturaplus_relations, :currency_exchange
  end
end