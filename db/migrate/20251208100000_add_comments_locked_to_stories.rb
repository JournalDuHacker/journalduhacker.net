class AddCommentsLockedToStories < ActiveRecord::Migration[8.1]
  def change
    add_column :stories, :comments_locked, :boolean, default: false, null: false
  end
end
