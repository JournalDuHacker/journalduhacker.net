class AddDraftToBlogPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :blog_posts, :draft, :boolean, default: false, null: false
    add_index :blog_posts, :draft
  end
end
