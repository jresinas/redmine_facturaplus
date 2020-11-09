class CreateSageArticles < ActiveRecord::Migration
  def self.up
    create_table :sage_articles, :force => true do |t|
      t.column :service_id, :integer, :null => false
      t.column :service_name, :string, :null => false
      t.column :article_id, :string, :null => false
    end
  end

  def self.down
    drop_table :sage_articles
  end
end