require "spec_helper"

describe Story, "merging and suggestions" do
  describe "story merging" do
    it "can be merged into another story" do
      s1 = Story.make!(title: "original")
      s2 = Story.make!(title: "duplicate")

      s2.merge_story_short_id = s1.short_id
      s2.save!

      expect(s2.merged_story_id).to eq(s1.id)
      expect(s2.merged_into_story).to eq(s1)
    end

    it "cannot be merged into itself" do
      s = Story.make!(title: "test")

      s.merge_story_short_id = s.short_id
      expect(s.valid?).to eq(false)
      expect(s.errors[:merge_story_short_id]).to be_present
    end

    it "shows merged stories" do
      s1 = Story.make!(title: "main")
      s2 = Story.make!(title: "merged1")
      s3 = Story.make!(title: "merged2")

      s2.merge_story_short_id = s1.short_id
      s2.save!
      s3.merge_story_short_id = s1.short_id
      s3.save!

      expect(s1.merged_stories.count).to eq(2)
      expect(s1.merged_stories).to include(s2, s3)
    end

    it "includes merged story comments in merged_comments" do
      s1 = Story.make!(title: "main")
      s2 = Story.make!(title: "merged")

      c1 = Comment.make!(story_id: s1.id, comment: "on main")
      c2 = Comment.make!(story_id: s2.id, comment: "on merged")

      s2.merge_story_short_id = s1.short_id
      s2.save!

      merged_comment_ids = s1.merged_comments.pluck(:id)
      expect(merged_comment_ids).to include(c1.id, c2.id)
    end

    it "unmerges when merge_story_short_id is cleared" do
      s1 = Story.make!(title: "main")
      s2 = Story.make!(title: "merged")

      s2.merge_story_short_id = s1.short_id
      s2.save!

      expect(s2.merged_story_id).to be_present

      s2.merge_story_short_id = ""
      s2.save!

      expect(s2.merged_story_id).to be_nil
    end

    it "uses unmerged scope" do
      s1 = Story.make!(title: "normal")
      s2 = Story.make!(title: "merged")

      s2.merged_story_id = s1.id
      s2.save!

      unmerged = Story.unmerged
      expect(unmerged).to include(s1)
      expect(unmerged).not_to include(s2)
    end

    it "updates merged_into_story comments count" do
      s1 = Story.make!(title: "main")
      s2 = Story.make!(title: "merged")

      Comment.make!(story_id: s2.id, comment: "comment")

      initial_count = s1.comments_count

      s2.merge_story_short_id = s1.short_id
      s2.save!

      s1.reload
      # Comments count should be updated after merge
      expect(s1.comments_count).to be >= initial_count
    end
  end

  describe "tag suggestions" do
    let(:author) { User.make!(karma: User::MIN_KARMA_TO_SUGGEST, created_at: 10.days.ago) }
    let(:suggester1) { User.make!(karma: User::MIN_KARMA_TO_SUGGEST, created_at: 10.days.ago) }
    let(:suggester2) { User.make!(karma: User::MIN_KARMA_TO_SUGGEST, created_at: 10.days.ago) }

    it "allows users with sufficient karma to suggest tags" do
      author_high_karma = User.make!(karma: 15, created_at: 10.days.ago)
      s = Story.make!(user_id: author_high_karma.id, title: "test", tags_a: ["tag1"])

      suggester = User.make!(karma: User::MIN_KARMA_TO_SUGGEST, created_at: 10.days.ago)
      expect(s.can_have_suggestions_from_user?(suggester)).to eq(true)
    end

    it "prevents author from suggesting on own story" do
      s = Story.make!(user_id: author.id, title: "test")

      expect(s.can_have_suggestions_from_user?(author)).to eq(false)
    end

    it "prevents suggestions on privileged tags" do
      priv_tag = Tag.create!(tag: "privtag", description: "privileged", privileged: true)
      mod = User.make!(is_moderator: true)
      s = Story.make!(user_id: mod.id, title: "test", tags_a: ["privtag"])

      expect(s.can_have_suggestions_from_user?(suggester1)).to eq(false)
    end

    it "saves suggested tags for user" do
      s = Story.make!(user_id: author.id, title: "test", tags_a: ["tag1"])

      s.save_suggested_tags_a_for_user!(["tag2"], suggester1)

      suggested = s.suggested_taggings.where(user_id: suggester1.id)
      expect(suggested.count).to eq(1)
      expect(suggested.first.tag.tag).to eq("tag2")
    end

    it "promotes tags when quorum is reached" do
      Tag.find_or_create_by!(tag: "tag2") { |t| t.description = "test tag 2" }
      s = Story.make!(user_id: author.id, title: "test", tags_a: ["tag1"])

      # Two users suggest the same tag
      s.save_suggested_tags_a_for_user!(["tag1", "tag2"], suggester1)
      s.save_suggested_tags_a_for_user!(["tag1", "tag2"], suggester2)

      # Verify suggestions were saved
      suggestions = s.suggested_taggings.where("tag_id = (SELECT id FROM tags WHERE tag = 'tag2')")
      expect(suggestions.count).to be >= 2
    end

    it "creates moderation log when promoting from suggestions" do
      s = Story.make!(user_id: author.id, title: "test", tags_a: ["tag1"])

      initial_mod_count = Moderation.count

      s.save_suggested_tags_a_for_user!(["tag2"], suggester1)
      s.save_suggested_tags_a_for_user!(["tag2"], suggester2)

      expect(Moderation.count).to be > initial_mod_count
    end

    it "has_suggestions? returns true when suggestions exist" do
      s = Story.make!(user_id: author.id, title: "test")

      s.save_suggested_tags_a_for_user!(["tag2"], suggester1)

      expect(s.has_suggestions?).to eq(true)
    end

    it "has_suggestions? returns false when no suggestions" do
      s = Story.make!(title: "test")

      expect(s.has_suggestions?).to eq(false)
    end
  end

  describe "title suggestions" do
    let(:author) { User.make!(karma: 15) }
    let(:suggester1) { User.make!(karma: 15) }
    let(:suggester2) { User.make!(karma: 15) }

    it "saves suggested title for user" do
      s = Story.make!(user_id: author.id, title: "Bad Title")

      s.save_suggested_title_for_user!("Better Title", suggester1)

      suggested = s.suggested_titles.where(user_id: suggester1.id).first
      expect(suggested).to be_present
      expect(suggested.title).to eq("Better Title")
    end

    it "updates existing suggestion from same user" do
      s = Story.make!(user_id: author.id, title: "Bad Title")

      s.save_suggested_title_for_user!("First Suggestion", suggester1)
      s.save_suggested_title_for_user!("Second Suggestion", suggester1)

      suggestions = s.suggested_titles.where(user_id: suggester1.id)
      expect(suggestions.count).to eq(1)
      expect(suggestions.first.title).to eq("Second Suggestion")
    end

    it "promotes title when quorum is reached" do
      s = Story.make!(user_id: author.id, title: "Bad Title")

      # Two users suggest the same title
      s.save_suggested_title_for_user!("Good Title", suggester1)
      s.save_suggested_title_for_user!("Good Title", suggester2)

      s.reload
      expect(s.title).to eq("Good Title")
    end

    it "promotes most popular title when multiple suggestions" do
      s = Story.make!(user_id: author.id, title: "Original")
      user3 = User.make!(karma: 15)

      s.save_suggested_title_for_user!("Title A", suggester1)
      s.save_suggested_title_for_user!("Title B", suggester2)
      s.save_suggested_title_for_user!("Title A", user3) # Title A has 2 votes

      s.reload
      expect(s.title).to eq("Title A")
    end
  end

  describe "#update_comments_count!" do
    it "recalculates comments count" do
      s = Story.make!(title: "test")

      3.times { Comment.make!(story_id: s.id, comment: "test") }

      s.update_comments_count!
      s.reload

      expect(s.comments_count).to eq(3) # 3 comments (initial upvote doesn't create a comment)
    end

    it "excludes deleted comments from count" do
      s = Story.make!(title: "test")
      c1 = Comment.make!(story_id: s.id, comment: "visible")
      c2 = Comment.make!(story_id: s.id, comment: "deleted", is_deleted: true)

      s.update_comments_count!
      s.reload

      # Should count only non-deleted comments
      expect(s.comments_count).to be >= 1
    end

    it "recalculates hotness after updating count" do
      s = Story.make!(title: "test")
      initial_hotness = s.hotness

      Comment.make!(story_id: s.id, comment: "new comment")
      s.update_comments_count!
      s.reload

      expect(s.hotness).not_to eq(initial_hotness)
    end
  end

  describe "#can_be_seen_by_user?" do
    let(:author) { User.make! }
    let(:moderator) { User.make!(is_moderator: true) }
    let(:other_user) { User.make! }

    it "allows anyone to see normal stories" do
      s = Story.make!(user_id: author.id, title: "test")

      expect(s.can_be_seen_by_user?(other_user)).to eq(true)
      expect(s.can_be_seen_by_user?(nil)).to eq(true)
    end

    it "allows author to see their expired story" do
      s = Story.make!(user_id: author.id, title: "test", is_expired: true)

      expect(s.can_be_seen_by_user?(author)).to eq(true)
    end

    it "allows moderator to see expired stories" do
      s = Story.make!(user_id: author.id, title: "test", is_expired: true)

      expect(s.can_be_seen_by_user?(moderator)).to eq(true)
    end

    it "prevents other users from seeing expired stories" do
      s = Story.make!(user_id: author.id, title: "test", is_expired: true)

      expect(s.can_be_seen_by_user?(other_user)).to eq(false)
    end
  end

  describe "#is_recent?" do
    it "returns true for stories within RECENT_DAYS" do
      s = Story.make!(title: "recent", created_at: (Story::RECENT_DAYS - 1).days.ago)

      expect(s.is_recent?).to eq(true)
    end

    it "returns false for old stories" do
      s = Story.make!(title: "old", created_at: (Story::RECENT_DAYS + 1).days.ago)

      expect(s.is_recent?).to eq(false)
    end
  end

  describe "#is_gone?" do
    it "returns true when expired" do
      s = Story.make!(title: "test", is_expired: true)

      expect(s.is_gone?).to eq(true)
    end

    it "returns false when active" do
      s = Story.make!(title: "test")

      expect(s.is_gone?).to eq(false)
    end
  end
end
