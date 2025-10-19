class AddUserAvatarPref < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :show_avatars, :boolean, :default => false
  end
end
