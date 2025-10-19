class InactiveTags < ActiveRecord::Migration[8.0]
  def change
    add_column :tags, :inactive, :boolean, :default => false
  end
end
