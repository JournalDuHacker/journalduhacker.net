require "spec_helper"

describe TagFilter do
  describe "associations" do
    it "belongs to tag" do
      user = User.make!
      tag = Tag.create!(tag: "test", description: "Test tag")
      filter = TagFilter.create!(user_id: user.id, tag_id: tag.id)

      expect(filter.tag).to eq(tag)
    end

    it "belongs to user" do
      user = User.make!
      tag = Tag.create!(tag: "test", description: "Test tag")
      filter = TagFilter.create!(user_id: user.id, tag_id: tag.id)

      expect(filter.user).to eq(user)
    end
  end

  describe "creation" do
    it "creates tag filter with user and tag" do
      user = User.make!
      tag = Tag.create!(tag: "unwanted", description: "Unwanted tag")

      filter = TagFilter.create!(user_id: user.id, tag_id: tag.id)

      expect(filter).to be_persisted
      expect(filter.user_id).to eq(user.id)
      expect(filter.tag_id).to eq(tag.id)
    end

    it "allows user to filter multiple tags" do
      user = User.make!
      tag1 = Tag.find_or_create_by!(tag: "filter_tag1") { |t| t.description = "Tag 1" }
      tag2 = Tag.find_or_create_by!(tag: "filter_tag2") { |t| t.description = "Tag 2" }

      TagFilter.create!(user_id: user.id, tag_id: tag1.id)
      TagFilter.create!(user_id: user.id, tag_id: tag2.id)

      expect(TagFilter.where(user_id: user.id).count).to eq(2)
    end

    it "allows multiple users to filter same tag" do
      user1 = User.make!
      user2 = User.make!
      tag = Tag.create!(tag: "spam", description: "Spam tag")

      TagFilter.create!(user_id: user1.id, tag_id: tag.id)
      TagFilter.create!(user_id: user2.id, tag_id: tag.id)

      expect(TagFilter.where(tag_id: tag.id).count).to eq(2)
    end
  end

  describe "filtering behavior" do
    it "hides stories with filtered tag from user" do
      user = User.make!
      tag = Tag.create!(tag: "filtered", description: "Filtered tag")
      TagFilter.create!(user_id: user.id, tag_id: tag.id)

      # Story with filtered tag
      story = Story.make!(tags_a: ["filtered"])

      # User's filtered tags
      filtered_tag_ids = TagFilter.where(user_id: user.id).pluck(:tag_id)
      story_tag_ids = story.taggings.pluck(:tag_id)

      # Check if story has any filtered tags
      has_filtered_tag = (story_tag_ids & filtered_tag_ids).any?
      expect(has_filtered_tag).to eq(true)
    end

    it "shows stories without filtered tag to user" do
      user = User.make!
      filtered_tag = Tag.create!(tag: "filtered", description: "Filtered tag")
      normal_tag = Tag.find_by(tag: "tag1") || Tag.create!(tag: "tag1", description: "Normal tag")
      TagFilter.create!(user_id: user.id, tag_id: filtered_tag.id)

      # Story without filtered tag
      story = Story.make!(tags_a: ["tag1"])

      # User's filtered tags
      filtered_tag_ids = TagFilter.where(user_id: user.id).pluck(:tag_id)
      story_tag_ids = story.taggings.pluck(:tag_id)

      # Check if story has any filtered tags
      has_filtered_tag = (story_tag_ids & filtered_tag_ids).any?
      expect(has_filtered_tag).to eq(false)
    end
  end

  describe "deletion" do
    it "removes filter when deleted" do
      user = User.make!
      tag = Tag.create!(tag: "test", description: "Test")
      filter = TagFilter.create!(user_id: user.id, tag_id: tag.id)

      filter.destroy

      expect(TagFilter.where(id: filter.id).first).to be_nil
    end

    it "doesn't delete user when filter is deleted" do
      user = User.make!
      tag = Tag.create!(tag: "test", description: "Test")
      filter = TagFilter.create!(user_id: user.id, tag_id: tag.id)

      filter.destroy

      expect(User.where(id: user.id).first).to be_present
    end

    it "doesn't delete tag when filter is deleted" do
      user = User.make!
      tag = Tag.create!(tag: "test", description: "Test")
      filter = TagFilter.create!(user_id: user.id, tag_id: tag.id)

      filter.destroy

      expect(Tag.where(id: tag.id).first).to be_present
    end
  end
end
