class CreateBlogPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_posts do |t|
      t.string :title, null: false
      t.string :slug, null: false, limit: 191
      t.integer :user_id, null: false
      t.text :body, null: false
      t.text :markeddown_body, null: false
      t.datetime :published_at, null: false

      t.timestamps
    end

    add_index :blog_posts, :slug, unique: true
    add_index :blog_posts, :published_at
    add_foreign_key :blog_posts, :users
  end
end
