class AddLegacyIdentifierToBlogPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :blog_posts, :legacy_identifier, :integer
    add_index :blog_posts, :legacy_identifier, unique: true
  end
end
