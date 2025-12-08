class ConvertDatabaseToUtf8mb4 < ActiveRecord::Migration[8.1]
  def up
    # List of all tables to convert
    tables = %w[
      comments
      hat_requests
      hats
      hidden_stories
      invitation_requests
      invitations
      keystores
      messages
      moderations
      stories
      suggested_taggings
      suggested_titles
      tag_filters
      taggings
      tags
      users
      votes
    ]

    # Convert each table to utf8mb4
    tables.each do |table|
      execute "ALTER TABLE `#{table}` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    end

    # Also convert the database default charset
    execute "ALTER DATABASE `#{ActiveRecord::Base.connection.current_database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
  end

  def down
    # Reverting to latin1 could cause data loss if emojis were inserted
    # This is intentionally left as a no-op with a warning
    raise ActiveRecord::IrreversibleMigration, "Cannot safely revert utf8mb4 conversion - emojis would be lost"
  end
end
