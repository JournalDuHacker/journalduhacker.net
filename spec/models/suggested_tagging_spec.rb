require "spec_helper"

describe SuggestedTagging do
  describe "associations" do
    it "belongs to tag" do
      user = User.make!
      story = Story.make!
      tag = Tag.create!(tag: "test", description: "Test tag")
      suggestion = SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag.id)

      expect(suggestion.tag).to eq(tag)
    end

    it "belongs to story" do
      user = User.make!
      story = Story.make!
      tag = Tag.create!(tag: "test", description: "Test tag")
      suggestion = SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag.id)

      expect(suggestion.story).to eq(story)
    end

    it "belongs to user" do
      user = User.make!
      story = Story.make!
      tag = Tag.create!(tag: "test", description: "Test tag")
      suggestion = SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag.id)

      expect(suggestion.user).to eq(user)
    end
  end

  describe "creation" do
    it "creates suggested tagging with all required fields" do
      user = User.make!(karma: 15, created_at: 10.days.ago)
      story = Story.make!
      tag = Tag.create!(tag: "ruby", description: "Ruby programming")

      suggestion = SuggestedTagging.create!(
        user_id: user.id,
        story_id: story.id,
        tag_id: tag.id
      )

      expect(suggestion).to be_persisted
      expect(suggestion.user_id).to eq(user.id)
      expect(suggestion.story_id).to eq(story.id)
      expect(suggestion.tag_id).to eq(tag.id)
    end

    it "allows multiple users to suggest same tag for story" do
      user1 = User.make!(karma: 15, created_at: 10.days.ago)
      user2 = User.make!(karma: 15, created_at: 10.days.ago)
      story = Story.make!
      tag = Tag.create!(tag: "javascript", description: "JavaScript")

      SuggestedTagging.create!(user_id: user1.id, story_id: story.id, tag_id: tag.id)
      SuggestedTagging.create!(user_id: user2.id, story_id: story.id, tag_id: tag.id)

      suggestions = SuggestedTagging.where(story_id: story.id, tag_id: tag.id)
      expect(suggestions.count).to eq(2)
    end

    it "allows user to suggest multiple tags for story" do
      user = User.make!(karma: 15, created_at: 10.days.ago)
      story = Story.make!
      tag1 = Tag.create!(tag: "ruby", description: "Ruby")
      tag2 = Tag.create!(tag: "rails", description: "Rails")

      SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag1.id)
      SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag2.id)

      suggestions = SuggestedTagging.where(user_id: user.id, story_id: story.id)
      expect(suggestions.count).to eq(2)
    end
  end

  describe "querying suggestions" do
    it "finds all suggestions for a story" do
      user = User.make!(karma: 15, created_at: 10.days.ago)
      story = Story.make!
      tag1 = Tag.find_or_create_by!(tag: "suggested_tag1") { |t| t.description = "Tag 1" }
      tag2 = Tag.find_or_create_by!(tag: "suggested_tag2") { |t| t.description = "Tag 2" }

      SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag1.id)
      SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag2.id)

      suggestions = SuggestedTagging.where(story_id: story.id)
      expect(suggestions.count).to eq(2)
    end

    it "finds all suggestions by a user" do
      user = User.make!(karma: 15, created_at: 10.days.ago)
      story1 = Story.make!
      story2 = Story.make!
      tag = Tag.create!(tag: "test", description: "Test")

      SuggestedTagging.create!(user_id: user.id, story_id: story1.id, tag_id: tag.id)
      SuggestedTagging.create!(user_id: user.id, story_id: story2.id, tag_id: tag.id)

      suggestions = SuggestedTagging.where(user_id: user.id)
      expect(suggestions.count).to eq(2)
    end

    it "finds suggestions for specific tag" do
      user = User.make!(karma: 15, created_at: 10.days.ago)
      story1 = Story.make!
      story2 = Story.make!
      tag = Tag.create!(tag: "popular", description: "Popular tag")

      SuggestedTagging.create!(user_id: user.id, story_id: story1.id, tag_id: tag.id)
      SuggestedTagging.create!(user_id: user.id, story_id: story2.id, tag_id: tag.id)

      suggestions = SuggestedTagging.where(tag_id: tag.id)
      expect(suggestions.count).to eq(2)
    end
  end

  describe "deletion" do
    it "removes suggestion when deleted" do
      user = User.make!
      story = Story.make!
      tag = Tag.create!(tag: "test", description: "Test")
      suggestion = SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag.id)

      suggestion.destroy

      expect(SuggestedTagging.where(id: suggestion.id).first).to be_nil
    end

    it "doesn't delete user when suggestion is deleted" do
      user = User.make!
      story = Story.make!
      tag = Tag.create!(tag: "test", description: "Test")
      suggestion = SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag.id)

      suggestion.destroy

      expect(User.where(id: user.id).first).to be_present
    end

    it "doesn't delete story when suggestion is deleted" do
      user = User.make!
      story = Story.make!
      tag = Tag.create!(tag: "test", description: "Test")
      suggestion = SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag.id)

      suggestion.destroy

      expect(Story.where(id: story.id).first).to be_present
    end

    it "doesn't delete tag when suggestion is deleted" do
      user = User.make!
      story = Story.make!
      tag = Tag.create!(tag: "test", description: "Test")
      suggestion = SuggestedTagging.create!(user_id: user.id, story_id: story.id, tag_id: tag.id)

      suggestion.destroy

      expect(Tag.where(id: tag.id).first).to be_present
    end
  end
end
