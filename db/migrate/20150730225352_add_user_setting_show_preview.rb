class AddUserSettingShowPreview < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :show_story_previews, :boolean, :default => false
  end
end
