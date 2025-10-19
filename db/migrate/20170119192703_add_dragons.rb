class AddDragons < ActiveRecord::Migration[8.0]
  def change
    add_column :comments, :is_dragon, :boolean, :default => false
  end
end
