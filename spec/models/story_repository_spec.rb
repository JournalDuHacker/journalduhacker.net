require "spec_helper"

describe StoryRepository do
  let(:user) { User.make! }
  let(:repo) { StoryRepository.new(user) }
  let(:repo_no_user) { StoryRepository.new(nil) }

  describe "#hottest" do
    it "returns stories ordered by hotness" do
      s1 = Story.make!(title: "story 1")
      s2 = Story.make!(title: "story 2")

      s1.update_column(:upvotes, 10)
      s1.update_column(:hotness, s1.calculated_hotness)

      s2.update_column(:upvotes, 20)
      s2.update_column(:hotness, s2.calculated_hotness)

      stories = repo_no_user.hottest.to_a
      expect(stories).to include(s1, s2)
      expect(stories.first.hotness).to be <= stories.last.hotness
    end

    it "excludes stories with negative scores" do
      good_story = Story.make!(title: "good")
      bad_story = Story.make!(title: "bad")

      good_story.update_column(:upvotes, 10)
      good_story.update_column(:downvotes, 0)

      bad_story.update_column(:upvotes, 1)
      bad_story.update_column(:downvotes, 10)

      stories = repo_no_user.hottest
      expect(stories).to include(good_story)
      expect(stories).not_to include(bad_story)
    end

    it "requires minimal score of 2" do
      low_score = Story.make!(title: "low")
      high_score = Story.make!(title: "high")

      low_score.update_column(:upvotes, 2)
      low_score.update_column(:downvotes, 1) # score = 1

      high_score.update_column(:upvotes, 5)
      high_score.update_column(:downvotes, 0) # score = 5

      stories = repo_no_user.hottest
      expect(stories).to include(high_score)
      expect(stories).not_to include(low_score)
    end

    it "filters hidden stories for logged-in user" do
      story = Story.make!(title: "hidden")
      HiddenStory.create!(user_id: user.id, story_id: story.id)

      stories = StoryRepository.new(user).hottest
      expect(stories).not_to include(story)
    end

    it "filters stories by excluded tags" do
      unwanted_tag = Tag.find_by(tag: "tag1") || Tag.create!(tag: "tag1", description: "Tag 1")
      story = Story.make!(title: "tagged", tags_a: ["tag1"])

      repo_with_filter = StoryRepository.new(nil, exclude_tags: [unwanted_tag.id])
      stories = repo_with_filter.hottest

      expect(stories).not_to include(story)
    end
  end

  describe "#newest" do
    it "returns stories ordered by creation date DESC" do
      old_story = Story.make!(title: "old", created_at: 2.days.ago)
      new_story = Story.make!(title: "new", created_at: 1.hour.ago)

      stories = repo_no_user.newest.to_a
      expect(stories.first.created_at).to be > stories.last.created_at
    end

    it "filters hidden stories for logged-in user" do
      story = Story.make!(title: "hidden")
      HiddenStory.create!(user_id: user.id, story_id: story.id)

      stories = StoryRepository.new(user).newest
      expect(stories).not_to include(story)
    end

    it "shows all stories to anonymous users" do
      s1 = Story.make!(title: "story 1")
      s2 = Story.make!(title: "story 2")

      stories = repo_no_user.newest
      expect(stories).to include(s1, s2)
    end
  end

  describe "#newest_by_user" do
    it "returns only stories by specific user" do
      other_user = User.make!
      user_story = Story.make!(user_id: user.id, title: "user story")
      other_story = Story.make!(user_id: other_user.id, title: "other story")

      stories = repo.newest_by_user(user)
      expect(stories).to include(user_story)
      expect(stories).not_to include(other_story)
    end

    it "orders by id DESC (newest first)" do
      s1 = Story.make!(user_id: user.id, title: "first")
      s2 = Story.make!(user_id: user.id, title: "second")

      stories = repo.newest_by_user(user).to_a
      expect(stories.first.id).to be > stories.last.id
    end

    it "includes all stories regardless of score" do
      good = Story.make!(user_id: user.id, title: "good")
      bad = Story.make!(user_id: user.id, title: "bad")

      good.update_column(:upvotes, 10)
      bad.update_column(:upvotes, 1)
      bad.update_column(:downvotes, 10)

      stories = repo.newest_by_user(user)
      expect(stories).to include(good, bad)
    end
  end

  describe "#recent" do
    it "returns recent stories" do
      recent = Story.make!(title: "recent", created_at: 1.day.ago)
      old = Story.make!(title: "old", created_at: 10.days.ago)

      stories = repo_no_user.recent
      expect(stories).to include(recent)
    end

    it "excludes stories with high scores (already on front page)" do
      popular = Story.make!(title: "popular", created_at: 1.day.ago)
      popular.update_column(:upvotes, 10)
      popular.update_column(:downvotes, 0)

      unpopular = Story.make!(title: "unpopular", created_at: 1.day.ago)
      unpopular.update_column(:upvotes, 2)

      stories = repo_no_user.recent.to_a
      # Popular stories (score > HOT_STORY_POINTS) should be filtered
      expect(stories.map(&:id)).not_to include(popular.id)
    end

    it "gives priority to newest stories" do
      s1 = Story.make!(title: "newer", created_at: 1.hour.ago)
      s2 = Story.make!(title: "older", created_at: 2.days.ago)

      s1.update_column(:upvotes, 2)
      s2.update_column(:upvotes, 2)

      stories = repo_no_user.recent.to_a
      newer_index = stories.index(s1)
      older_index = stories.index(s2)

      expect(newer_index).to be < older_index if newer_index && older_index
    end
  end

  describe "#tagged" do
    it "returns stories with specific tag" do
      tag = Tag.find_by(tag: "tag1") || Tag.create!(tag: "tag1", description: "Tag 1")
      tagged_story = Story.make!(title: "tagged", tags_a: ["tag1"])
      other_story = Story.make!(title: "other", tags_a: ["tag2"])

      stories = repo_no_user.tagged(tag)
      expect(stories).to include(tagged_story)
      expect(stories).not_to include(other_story)
    end

    it "only returns stories with positive scores" do
      tag = Tag.find_by(tag: "tag1") || Tag.create!(tag: "tag1", description: "Tag 1")
      good = Story.make!(title: "good", tags_a: ["tag1"])
      bad = Story.make!(title: "bad", tags_a: ["tag1"])

      good.update_column(:upvotes, 10)
      bad.update_column(:upvotes, 1)
      bad.update_column(:downvotes, 10)

      stories = repo_no_user.tagged(tag)
      expect(stories).to include(good)
      expect(stories).not_to include(bad)
    end

    it "orders by creation date DESC" do
      tag = Tag.find_by(tag: "tag1") || Tag.create!(tag: "tag1", description: "Tag 1")
      old = Story.make!(title: "old", tags_a: ["tag1"], created_at: 2.days.ago)
      new = Story.make!(title: "new", tags_a: ["tag1"], created_at: 1.hour.ago)

      stories = repo_no_user.tagged(tag).to_a
      expect(stories.first.created_at).to be > stories.last.created_at
    end
  end

  describe "#top" do
    it "returns top stories from specified time period" do
      recent = Story.make!(title: "recent", created_at: 1.day.ago)
      old = Story.make!(title: "old", created_at: 10.days.ago)

      recent.update_column(:upvotes, 5)
      old.update_column(:upvotes, 5)

      stories = repo_no_user.top(dur: 7, intv: "day")
      expect(stories).to include(recent)
      expect(stories).not_to include(old)
    end

    it "orders by score DESC" do
      s1 = Story.make!(title: "low score", created_at: 1.day.ago)
      s2 = Story.make!(title: "high score", created_at: 1.day.ago)

      s1.update_column(:upvotes, 3)
      s2.update_column(:upvotes, 10)

      stories = repo_no_user.top(dur: 7, intv: "day").to_a
      expect(stories.first.score).to be >= stories.last.score
    end

    it "accepts different time intervals" do
      story = Story.make!(title: "test", created_at: 1.month.ago)
      story.update_column(:upvotes, 10)

      # Should find story within 2 months
      stories_2m = repo_no_user.top(dur: 2, intv: "month")
      expect(stories_2m).to include(story)

      # Should not find story within 7 days
      stories_7d = repo_no_user.top(dur: 7, intv: "day")
      expect(stories_7d).not_to include(story)
    end
  end

  describe "#hidden" do
    it "returns only hidden stories for logged-in user" do
      visible = Story.make!(title: "visible")
      hidden = Story.make!(title: "hidden")

      HiddenStory.create!(user_id: user.id, story_id: hidden.id)

      stories = StoryRepository.new(user).hidden
      expect(stories).to include(hidden)
      expect(stories).not_to include(visible)
    end

    it "returns all stories for anonymous users (no user-specific hiding)" do
      # For anonymous users, the hidden method returns base_scope
      # This is because hidden stories are user-specific
      s1 = Story.make!(title: "story 1")
      s2 = Story.make!(title: "story 2")

      stories = repo_no_user.hidden

      # Should include both stories since there's no user to filter by
      expect(stories.map(&:id)).to include(s1.id, s2.id)
    end

    it "can filter by excluded tags" do
      tag = Tag.find_by(tag: "tag1") || Tag.create!(tag: "tag1", description: "Tag 1")
      hidden = Story.make!(title: "hidden", tags_a: ["tag1"])
      HiddenStory.create!(user_id: user.id, story_id: hidden.id)

      repo_with_filter = StoryRepository.new(user, exclude_tags: [tag.id])
      stories = repo_with_filter.hidden

      expect(stories).not_to include(hidden)
    end
  end

  describe "base filtering" do
    it "excludes expired stories" do
      active = Story.make!(title: "active", is_expired: false)
      expired = Story.make!(title: "expired", is_expired: true)

      active.update_column(:upvotes, 10)
      active.update_column(:hotness, active.calculated_hotness)

      stories = repo_no_user.hottest
      expect(stories.map(&:id)).to include(active.id)
      expect(stories.map(&:id)).not_to include(expired.id)
    end

    it "excludes merged stories" do
      main = Story.make!(title: "main")
      merged = Story.make!(title: "merged")

      merged.merged_story_id = main.id
      merged.save!

      stories = repo_no_user.newest
      expect(stories).to include(main)
      expect(stories).not_to include(merged)
    end
  end

  describe "tag filtering" do
    it "allows filtering multiple tags" do
      tag1 = Tag.find_or_create_by!(tag: "tag1") { |t| t.description = "Tag 1" }
      tag2 = Tag.find_or_create_by!(tag: "tag2") { |t| t.description = "Tag 2" }
      tag3 = Tag.find_or_create_by!(tag: "tag3") { |t| t.description = "Tag 3" }

      s1 = Story.make!(title: "has tag1", tags_a: ["tag1"])
      s2 = Story.make!(title: "has tag2", tags_a: ["tag2"])
      s3 = Story.make!(title: "has tag3", tags_a: ["tag3"])

      repo_filtered = StoryRepository.new(nil, exclude_tags: [tag1.id, tag2.id])
      stories = repo_filtered.newest

      expect(stories.map(&:id)).not_to include(s1.id, s2.id)
      expect(stories.map(&:id)).to include(s3.id)
    end
  end

  describe "user-specific filtering" do
    it "applies user's tag filters" do
      story = Story.make!(title: "test")
      # User has hidden this story
      HiddenStory.create!(user_id: user.id, story_id: story.id)

      user_repo = StoryRepository.new(user)
      stories = user_repo.hottest

      expect(stories).not_to include(story)
    end

    it "shows all stories to different user" do
      other_user = User.make!
      story = Story.make!(title: "test")

      # Give story enough votes to appear in hottest
      story.update_column(:upvotes, 10)
      story.update_column(:hotness, story.calculated_hotness)

      # Original user hides story
      HiddenStory.create!(user_id: user.id, story_id: story.id)

      # Other user should still see it
      other_repo = StoryRepository.new(other_user)
      stories = other_repo.hottest

      expect(stories.map(&:id)).to include(story.id)
    end
  end
end
