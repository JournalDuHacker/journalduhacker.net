class AddStoryUnavailable < ActiveRecord::Migration[8.0]
  def change
    add_column :stories, :unavailable_at, :datetime
  end
end
