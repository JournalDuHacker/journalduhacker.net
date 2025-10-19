class AddFulltextIndexes < ActiveRecord::Migration[8.0]
  def up
    # Add FULLTEXT index on stories table
    execute "ALTER TABLE stories ADD FULLTEXT INDEX fulltext_stories (title, description, url)"

    # Add FULLTEXT index on comments table
    execute "ALTER TABLE comments ADD FULLTEXT INDEX fulltext_comments (comment)"
  end

  def down
    # Remove FULLTEXT indexes
    execute "ALTER TABLE stories DROP INDEX fulltext_stories"
    execute "ALTER TABLE comments DROP INDEX fulltext_comments"
  end
end
