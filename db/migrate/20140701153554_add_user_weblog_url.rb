class AddUserWeblogUrl < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :weblog_feed_url, :string, :length => 500
  end
end
