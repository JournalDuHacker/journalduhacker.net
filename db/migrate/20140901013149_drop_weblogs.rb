class DropWeblogs < ActiveRecord::Migration[8.0]
  def change
    drop_table :weblogs
    remove_column :users, :weblog_feed_url
  end
end
