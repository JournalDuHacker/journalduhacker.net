require "spec_helper"

describe SuggestedTitle do
  describe "associations" do
    it "belongs to story" do
      user = User.make!
      story = Story.make!
      suggestion = SuggestedTitle.create!(
        user_id: user.id,
        story_id: story.id,
        title: "Better Title"
      )

      expect(suggestion.story).to eq(story)
    end

    it "belongs to user" do
      user = User.make!
      story = Story.make!
      suggestion = SuggestedTitle.create!(
        user_id: user.id,
        story_id: story.id,
        title: "Better Title"
      )

      expect(suggestion.user).to eq(user)
    end
  end

  describe "creation" do
    it "creates suggested title with all required fields" do
      user = User.make!(karma: 15)
      story = Story.make!(title: "Original Title")

      suggestion = SuggestedTitle.create!(
        user_id: user.id,
        story_id: story.id,
        title: "Improved Title"
      )

      expect(suggestion).to be_persisted
      expect(suggestion.user_id).to eq(user.id)
      expect(suggestion.story_id).to eq(story.id)
      expect(suggestion.title).to eq("Improved Title")
    end

    it "allows multiple users to suggest titles for same story" do
      user1 = User.make!(karma: 15)
      user2 = User.make!(karma: 15)
      story = Story.make!(title: "Original")

      SuggestedTitle.create!(user_id: user1.id, story_id: story.id, title: "Title A")
      SuggestedTitle.create!(user_id: user2.id, story_id: story.id, title: "Title B")

      suggestions = SuggestedTitle.where(story_id: story.id)
      expect(suggestions.count).to eq(2)
    end

    it "allows user to suggest titles for multiple stories" do
      user = User.make!(karma: 15)
      story1 = Story.make!(title: "Story 1")
      story2 = Story.make!(title: "Story 2")

      SuggestedTitle.create!(user_id: user.id, story_id: story1.id, title: "Better Story 1")
      SuggestedTitle.create!(user_id: user.id, story_id: story2.id, title: "Better Story 2")

      suggestions = SuggestedTitle.where(user_id: user.id)
      expect(suggestions.count).to eq(2)
    end

    it "stores exact title text as suggested" do
      user = User.make!(karma: 15)
      story = Story.make!
      suggested_text = "This is a Very Specific Title Format"

      suggestion = SuggestedTitle.create!(
        user_id: user.id,
        story_id: story.id,
        title: suggested_text
      )

      expect(suggestion.title).to eq(suggested_text)
    end
  end

  describe "querying suggestions" do
    it "finds all suggestions for a story" do
      user1 = User.make!(karma: 15)
      user2 = User.make!(karma: 15)
      story = Story.make!

      SuggestedTitle.create!(user_id: user1.id, story_id: story.id, title: "Title A")
      SuggestedTitle.create!(user_id: user2.id, story_id: story.id, title: "Title B")

      suggestions = SuggestedTitle.where(story_id: story.id)
      expect(suggestions.count).to eq(2)
    end

    it "finds all suggestions by a user" do
      user = User.make!(karma: 15)
      story1 = Story.make!
      story2 = Story.make!

      SuggestedTitle.create!(user_id: user.id, story_id: story1.id, title: "Title 1")
      SuggestedTitle.create!(user_id: user.id, story_id: story2.id, title: "Title 2")

      suggestions = SuggestedTitle.where(user_id: user.id)
      expect(suggestions.count).to eq(2)
    end

    it "can find suggestions by title text" do
      user = User.make!(karma: 15)
      story = Story.make!
      title_text = "Unique Title Text"

      SuggestedTitle.create!(user_id: user.id, story_id: story.id, title: title_text)

      suggestion = SuggestedTitle.where(title: title_text).first
      expect(suggestion).to be_present
      expect(suggestion.title).to eq(title_text)
    end

    it "groups suggestions by title for counting votes" do
      user1 = User.make!(karma: 15)
      user2 = User.make!(karma: 15)
      user3 = User.make!(karma: 15)
      story = Story.make!

      # Two users suggest same title
      SuggestedTitle.create!(user_id: user1.id, story_id: story.id, title: "Popular Title")
      SuggestedTitle.create!(user_id: user2.id, story_id: story.id, title: "Popular Title")
      SuggestedTitle.create!(user_id: user3.id, story_id: story.id, title: "Different Title")

      popular_count = SuggestedTitle.where(story_id: story.id, title: "Popular Title").count
      expect(popular_count).to eq(2)
    end
  end

  describe "updating suggestions" do
    it "allows user to update their suggestion" do
      user = User.make!(karma: 15)
      story = Story.make!
      suggestion = SuggestedTitle.create!(
        user_id: user.id,
        story_id: story.id,
        title: "First Suggestion"
      )

      suggestion.update!(title: "Updated Suggestion")

      suggestion.reload
      expect(suggestion.title).to eq("Updated Suggestion")
    end

    it "keeps same user and story when updating title" do
      user = User.make!(karma: 15)
      story = Story.make!
      suggestion = SuggestedTitle.create!(
        user_id: user.id,
        story_id: story.id,
        title: "Original"
      )

      suggestion.update!(title: "Updated")

      suggestion.reload
      expect(suggestion.user_id).to eq(user.id)
      expect(suggestion.story_id).to eq(story.id)
    end
  end

  describe "deletion" do
    it "removes suggestion when deleted" do
      user = User.make!
      story = Story.make!
      suggestion = SuggestedTitle.create!(
        user_id: user.id,
        story_id: story.id,
        title: "Test Title"
      )

      suggestion.destroy

      expect(SuggestedTitle.where(id: suggestion.id).first).to be_nil
    end

    it "doesn't delete user when suggestion is deleted" do
      user = User.make!
      story = Story.make!
      suggestion = SuggestedTitle.create!(
        user_id: user.id,
        story_id: story.id,
        title: "Test Title"
      )

      suggestion.destroy

      expect(User.where(id: user.id).first).to be_present
    end

    it "doesn't delete story when suggestion is deleted" do
      user = User.make!
      story = Story.make!
      suggestion = SuggestedTitle.create!(
        user_id: user.id,
        story_id: story.id,
        title: "Test Title"
      )

      suggestion.destroy

      expect(Story.where(id: story.id).first).to be_present
    end
  end
end
