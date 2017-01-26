class CreateFacturaplusRelations < ActiveRecord::Migration
  def self.up
    create_table :facturaplus_relations, :force => true do |t|
      t.column :issue_id, :integer, :null => false
      t.column :order_id, :integer, :null => true
      t.column :delivery_note_id, :integer, :null => true
      t.column :biller_id, :integer, :null => false
      t.column :client_id, :integer, :null => false
      t.column :amount, :float, :null => false
    end
  end

  def self.down
    drop_table :facturaplus_relations
  end
end