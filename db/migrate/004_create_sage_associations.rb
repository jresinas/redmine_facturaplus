class CreateSageAssociations < ActiveRecord::Migration
  def self.up
    create_table :sage_associations, :force => true do |t|
      t.column :source_id, :integer, :null => false
      t.column :source_name, :string, :null => false
      t.column :target_code, :string, :null => false
      t.column :data_type, :string, :null => false
    end
  end

  def self.down
    drop_table :sage_associations
  end
end