require "spec_helper"

describe Tagging do
  describe "associations" do
    it "belongs to tag" do
      tag = Tag.create!(tag: "test", description: "Test tag")
      story = Story.make!
      tagging = Tagging.create!(tag_id: tag.id, story_id: story.id)

      expect(tagging.tag).to eq(tag)
    end

    it "belongs to story" do
      tag = Tag.create!(tag: "test", description: "Test tag")
      story = Story.make!
      tagging = Tagging.create!(tag_id: tag.id, story_id: story.id)

      expect(tagging.story).to eq(story)
    end
  end

  describe "creation" do
    it "creates tagging with tag and story" do
      tag = Tag.create!(tag: "ruby", description: "Ruby programming")
      story = Story.make!

      tagging = Tagging.create!(tag_id: tag.id, story_id: story.id)

      expect(tagging).to be_persisted
      expect(tagging.tag_id).to eq(tag.id)
      expect(tagging.story_id).to eq(story.id)
    end

    it "links story to tag through tagging" do
      tag = Tag.create!(tag: "programming", description: "Programming")
      story = Story.make!

      Tagging.create!(tag_id: tag.id, story_id: story.id)

      expect(tag.stories).to include(story)
      expect(story.tags).to include(tag)
    end
  end

  describe "multiple taggings" do
    it "allows story to have multiple tags" do
      tag1 = Tag.find_or_create_by!(tag: "tagging_ruby") { |t| t.description = "Ruby" }
      tag2 = Tag.find_or_create_by!(tag: "tagging_rails") { |t| t.description = "Rails" }
      story = Story.make!

      initial_count = story.taggings.count

      Tagging.create!(tag_id: tag1.id, story_id: story.id)
      Tagging.create!(tag_id: tag2.id, story_id: story.id)

      story.reload
      expect(story.taggings.count).to eq(initial_count + 2)
      expect(story.tags).to include(tag1, tag2)
    end

    it "allows tag to be used on multiple stories" do
      tag = Tag.create!(tag: "javascript", description: "JavaScript")
      story1 = Story.make!
      story2 = Story.make!

      Tagging.create!(tag_id: tag.id, story_id: story1.id)
      Tagging.create!(tag_id: tag.id, story_id: story2.id)

      expect(tag.taggings.count).to eq(2)
      expect(tag.stories).to include(story1, story2)
    end
  end

  describe "deletion" do
    it "removes tagging when deleted" do
      tag = Tag.create!(tag: "test", description: "Test")
      story = Story.make!
      tagging = Tagging.create!(tag_id: tag.id, story_id: story.id)

      tagging.destroy

      expect(Tagging.where(id: tagging.id).first).to be_nil
    end

    it "doesn't delete tag when tagging is deleted" do
      tag = Tag.create!(tag: "test", description: "Test")
      story = Story.make!
      tagging = Tagging.create!(tag_id: tag.id, story_id: story.id)

      tagging.destroy

      expect(Tag.where(id: tag.id).first).to be_present
    end

    it "doesn't delete story when tagging is deleted" do
      tag = Tag.create!(tag: "test", description: "Test")
      story = Story.make!
      tagging = Tagging.create!(tag_id: tag.id, story_id: story.id)

      tagging.destroy

      expect(Story.where(id: story.id).first).to be_present
    end
  end
end
