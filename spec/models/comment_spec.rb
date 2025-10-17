require "spec_helper"

describe Comment do
  describe "short_id generation" do
    it "should get a short id" do
      c = Comment.make!(comment: "hello")
      expect(c.short_id).to match(/^\A[a-zA-Z0-9]{1,10}\z/)
    end

    it "should have unique short_ids" do
      c1 = Comment.make!(comment: "first")
      c2 = Comment.make!(comment: "second")
      expect(c1.short_id).not_to eq(c2.short_id)
    end
  end

  describe "validations" do
    it "requires a comment" do
      expect {
        Comment.make!(comment: "")
      }.to raise_error
    end

    it "requires a user_id" do
      expect {
        Comment.make!(user_id: nil)
      }.to raise_error
    end

    it "requires a story_id" do
      expect {
        Comment.make!(story_id: nil)
      }.to raise_error
    end

    it "rejects 'this' as a comment" do
      expect {
        Comment.make!(comment: "this")
      }.to raise_error
    end

    it "rejects 'This.' as a comment" do
      expect {
        Comment.make!(comment: "This.")
      }.to raise_error
    end

    it "rejects 'tldr' as a comment" do
      expect {
        Comment.make!(comment: "tldr")
      }.to raise_error
    end

    it "rejects 'me too' as a comment" do
      expect {
        Comment.make!(comment: "me too")
      }.to raise_error
    end
  end

  describe "threading" do
    it "assigns a thread_id to top-level comments" do
      c = Comment.make!(comment: "top level comment")
      expect(c.thread_id).to be_present
    end

    it "assigns same thread_id to child comments" do
      parent = Comment.make!(comment: "parent")
      child = Comment.make!(comment: "child", parent_comment_id: parent.id, story_id: parent.story_id)

      expect(child.thread_id).to eq(parent.thread_id)
    end

    it "maintains thread_id through multiple levels" do
      parent = Comment.make!(comment: "parent")
      child = Comment.make!(comment: "child", parent_comment_id: parent.id, story_id: parent.story_id)
      grandchild = Comment.make!(comment: "grandchild", parent_comment_id: child.id, story_id: parent.story_id)

      expect(grandchild.thread_id).to eq(parent.thread_id)
      expect(child.thread_id).to eq(parent.thread_id)
    end
  end

  describe "confidence calculation" do
    it "calculates confidence with Wilson score" do
      c = Comment.make!(comment: "test")
      c.upvotes = 10
      c.downvotes = 2

      confidence = c.calculated_confidence
      expect(confidence).to be > 0
      expect(confidence).to be < 1
    end

    it "returns 0 confidence when no votes" do
      c = Comment.make!(comment: "test")
      c.upvotes = 0
      c.downvotes = 0

      expect(c.calculated_confidence).to eq(0)
    end

    it "has higher confidence with more upvotes" do
      c1 = Comment.make!(comment: "test1")
      c1.upvotes = 10
      c1.downvotes = 0

      c2 = Comment.make!(comment: "test2")
      c2.upvotes = 5
      c2.downvotes = 0

      expect(c1.calculated_confidence).to be > c2.calculated_confidence
    end

    it "assigns initial confidence on creation" do
      c = Comment.make!(comment: "test")
      expect(c.confidence).to be_present
    end
  end

  describe "score" do
    it "calculates score as upvotes - downvotes" do
      c = Comment.make!(comment: "test")
      c.upvotes = 10
      c.downvotes = 3

      expect(c.score).to eq(7)
    end

    it "shows score to moderators" do
      mod = User.make!(is_moderator: true)
      c = Comment.make!(comment: "test")

      expect(c.score_for_user(mod)).to eq(c.score)
    end

    it "shows score for old comments" do
      user = User.make!
      c = Comment.make!(comment: "test", created_at: 37.hours.ago)

      expect(c.score_for_user(user)).to eq(c.score)
    end

    it "hides score for recent comments in range" do
      user = User.make!
      c = Comment.make!(comment: "test", created_at: 1.hour.ago)
      c.upvotes = 3
      c.downvotes = 1

      expect(c.score_for_user(user)).to eq("-")
    end
  end

  describe "permissions" do
    let(:author) { User.make! }
    let(:other_user) { User.make! }
    let(:moderator) { User.make!(is_moderator: true) }

    describe "is_editable_by_user?" do
      it "allows author to edit their own recent comment" do
        c = Comment.make!(user_id: author.id, comment: "test")
        expect(c.is_editable_by_user?(author)).to eq(true)
      end

      it "prevents editing after MAX_EDIT_MINS" do
        c = Comment.make!(user_id: author.id, comment: "test")
        c.update_column(:created_at, (Comment::MAX_EDIT_MINS + 1).minutes.ago)
        c.update_column(:updated_at, (Comment::MAX_EDIT_MINS + 1).minutes.ago)
        c.reload
        expect(c.is_editable_by_user?(author)).to eq(false)
      end

      it "prevents other users from editing" do
        c = Comment.make!(user_id: author.id, comment: "test")
        expect(c.is_editable_by_user?(other_user)).to eq(false)
      end

      it "prevents editing moderated comments" do
        c = Comment.make!(user_id: author.id, comment: "test", is_moderated: true)
        expect(c.is_editable_by_user?(author)).to eq(false)
      end
    end

    describe "is_deletable_by_user?" do
      it "allows author to delete their own comment" do
        c = Comment.make!(user_id: author.id, comment: "test")
        expect(c.is_deletable_by_user?(author)).to eq(true)
      end

      it "allows moderator to delete any comment" do
        c = Comment.make!(user_id: author.id, comment: "test")
        expect(c.is_deletable_by_user?(moderator)).to eq(true)
      end

      it "prevents other users from deleting" do
        c = Comment.make!(user_id: author.id, comment: "test")
        expect(c.is_deletable_by_user?(other_user)).to eq(false)
      end
    end

    describe "is_undeletable_by_user?" do
      it "allows moderator to undelete any comment" do
        c = Comment.make!(user_id: author.id, comment: "test", is_deleted: true)
        expect(c.is_undeletable_by_user?(moderator)).to eq(true)
      end

      it "allows author to undelete non-moderated comment" do
        c = Comment.make!(user_id: author.id, comment: "test", is_deleted: true)
        expect(c.is_undeletable_by_user?(author)).to eq(true)
      end

      it "prevents author from undeleting moderated comment" do
        c = Comment.make!(user_id: author.id, comment: "test", is_deleted: true, is_moderated: true)
        expect(c.is_undeletable_by_user?(author)).to eq(false)
      end
    end
  end

  describe "downvoting" do
    it "is downvotable when recent and above min score" do
      c = Comment.make!(comment: "test", created_at: 1.day.ago)
      c.upvotes = 5
      c.downvotes = 0

      expect(c.is_downvotable?).to eq(true)
    end

    it "is not downvotable when score is too low" do
      c = Comment.make!(comment: "test", created_at: 1.day.ago)
      c.upvotes = 1
      c.downvotes = 7

      expect(c.is_downvotable?).to eq(false)
    end

    it "is not downvotable when too old" do
      c = Comment.make!(comment: "test", created_at: (Comment::DOWNVOTABLE_DAYS + 1).days.ago)

      expect(c.is_downvotable?).to eq(false)
    end
  end

  describe "deletion" do
    let(:author) { User.make! }
    let(:moderator) { User.make!(is_moderator: true) }

    it "marks comment as deleted by author" do
      c = Comment.make!(user_id: author.id, comment: "test")
      c.delete_for_user(author)

      expect(c.is_deleted).to eq(true)
      expect(c.is_moderated).to eq(false)
    end

    it "marks comment as moderated when deleted by moderator" do
      c = Comment.make!(user_id: author.id, comment: "test")
      c.delete_for_user(moderator, "spam")

      expect(c.is_deleted).to eq(true)
      expect(c.is_moderated).to eq(true)
    end

    it "creates moderation log when deleted by moderator" do
      c = Comment.make!(user_id: author.id, comment: "test")
      initial_count = Moderation.count

      c.delete_for_user(moderator, "spam")

      expect(Moderation.count).to eq(initial_count + 1)
      mod = Moderation.last
      expect(mod.comment_id).to eq(c.id)
      expect(mod.moderator_user_id).to eq(moderator.id)
      expect(mod.reason).to eq("spam")
    end

    it "can be undeleted by author" do
      c = Comment.make!(user_id: author.id, comment: "test")
      c.delete_for_user(author)
      c.undelete_for_user(author)

      expect(c.is_deleted).to eq(false)
    end

    it "can be undeleted by moderator" do
      c = Comment.make!(user_id: author.id, comment: "test")
      c.delete_for_user(moderator, "spam")
      c.undelete_for_user(moderator)

      expect(c.is_deleted).to eq(false)
      expect(c.is_moderated).to eq(false)
    end
  end

  describe "is_gone?" do
    it "returns true when deleted" do
      c = Comment.make!(comment: "test", is_deleted: true)
      expect(c.is_gone?).to eq(true)
    end

    it "returns true when moderated" do
      c = Comment.make!(comment: "test", is_moderated: true)
      expect(c.is_gone?).to eq(true)
    end

    it "returns false when active" do
      c = Comment.make!(comment: "test")
      expect(c.is_gone?).to eq(false)
    end
  end

  describe "gone_text" do
    let(:author) { User.make! }
    let(:moderator) { User.make!(is_moderator: true, username: "mod_user") }

    it "shows moderation message when moderated" do
      c = Comment.make!(user_id: author.id, comment: "test", is_moderated: true)
      m = Moderation.create!(comment_id: c.id, moderator_user_id: moderator.id, reason: "spam")

      text = c.gone_text
      expect(text).to include("mod_user")
      expect(text).to include("spam")
    end

    it "shows banned user message when user is banned" do
      banned_user = User.make!(:banned)
      c = Comment.make!(user_id: banned_user.id, comment: "test", is_deleted: true)

      expect(c.gone_text).to eq("Comment from banned user removed")
    end

    it "shows author removal message" do
      c = Comment.make!(user_id: author.id, comment: "test", is_deleted: true)

      expect(c.gone_text).to eq("Comment removed by author")
    end
  end

  describe "has_been_edited?" do
    it "returns false for newly created comment" do
      c = Comment.make!(comment: "test")
      expect(c.has_been_edited?).to eq(false)
    end

    it "returns true when updated more than 1 minute after creation" do
      c = Comment.make!(comment: "test", created_at: 10.minutes.ago, updated_at: 5.minutes.ago)
      expect(c.has_been_edited?).to eq(true)
    end

    it "returns false when updated within 1 minute" do
      c = Comment.make!(comment: "test", created_at: 2.minutes.ago, updated_at: 1.5.minutes.ago)
      expect(c.has_been_edited?).to eq(false)
    end
  end

  describe "markdown" do
    it "converts comment to markdown on save" do
      c = Comment.make!(comment: "**bold**")
      expect(c.markeddown_comment).to include("<strong>")
    end

    it "generates markeddown_comment" do
      c = Comment.make!(comment: "*italic*")
      expect(c.generated_markeddown_comment).to include("<em>")
    end
  end

  describe "html_class_for_user" do
    it "returns inactive_user for inactive users" do
      banned_user = User.make!(:banned)
      c = Comment.make!(user_id: banned_user.id, comment: "test")

      expect(c.html_class_for_user).to eq("inactive_user")
    end

    it "returns new_user for new users" do
      new_user = User.make!(created_at: Time.now)
      c = Comment.make!(user_id: new_user.id, comment: "test")

      expect(c.html_class_for_user).to eq("new_user")
    end

    it "returns user_is_author when commenting on own story" do
      author = User.make!(created_at: 30.days.ago) # Not a new user
      story = Story.make!(user_id: author.id, user_is_author: true, url: nil, description: "story text")
      c = Comment.make!(user_id: author.id, story_id: story.id, comment: "test")

      expect(c.html_class_for_user).to eq("user_is_author")
    end
  end

  describe "URLs" do
    it "generates correct short_id_url" do
      c = Comment.make!(comment: "test")
      expect(c.short_id_url).to include("c/#{c.short_id}")
    end

    it "generates correct url with story anchor" do
      c = Comment.make!(comment: "test")
      expect(c.url).to include("#c_#{c.short_id}")
    end

    it "generates correct path" do
      c = Comment.make!(comment: "test")
      expect(c.path).to include("/comments/#{c.short_id}")
    end

    it "uses short_id as to_param" do
      c = Comment.make!(comment: "test")
      expect(c.to_param).to eq(c.short_id)
    end
  end

  describe ".arrange_for_user" do
    it "orders comments by confidence" do
      story = Story.make!
      c1 = Comment.make!(story_id: story.id, comment: "low confidence")
      c2 = Comment.make!(story_id: story.id, comment: "high confidence")

      c1.update_column(:upvotes, 1)
      c1.update_column(:downvotes, 0)
      c1.update_column(:confidence, c1.calculated_confidence)

      c2.update_column(:upvotes, 10)
      c2.update_column(:downvotes, 0)
      c2.update_column(:confidence, c2.calculated_confidence)

      comments = story.comments.reload.arrange_for_user(nil)
      # Comment with higher confidence (c2) should appear first
      expect(comments.first.confidence).to be > comments.last.confidence
    end

    it "removes deleted comments without children" do
      story = Story.make!
      c1 = Comment.make!(story_id: story.id, comment: "normal", is_deleted: false)
      c2 = Comment.make!(story_id: story.id, comment: "deleted", is_deleted: true)

      comments = story.comments.arrange_for_user(nil)
      expect(comments.map(&:id)).to include(c1.id)
      expect(comments.map(&:id)).not_to include(c2.id)
    end

    it "keeps deleted comments with children" do
      story = Story.make!
      parent = Comment.make!(story_id: story.id, comment: "parent", is_deleted: true)
      child = Comment.make!(story_id: story.id, comment: "child", parent_comment_id: parent.id)

      comments = story.comments.arrange_for_user(nil)
      expect(comments.map(&:id)).to include(parent.id)
      expect(comments.map(&:id)).to include(child.id)
    end

    it "assigns correct indent levels" do
      story = Story.make!
      parent = Comment.make!(story_id: story.id, comment: "parent")
      child = Comment.make!(story_id: story.id, comment: "child", parent_comment_id: parent.id)
      grandchild = Comment.make!(story_id: story.id, comment: "grandchild", parent_comment_id: child.id)

      comments = story.comments.arrange_for_user(nil)

      parent_arranged = comments.find { |c| c.id == parent.id }
      child_arranged = comments.find { |c| c.id == child.id }
      grandchild_arranged = comments.find { |c| c.id == grandchild.id }

      expect(parent_arranged.indent_level).to eq(1)
      expect(child_arranged.indent_level).to eq(2)
      expect(grandchild_arranged.indent_level).to eq(3)
    end
  end

  describe "active scope" do
    it "excludes deleted comments" do
      c1 = Comment.make!(comment: "active")
      c2 = Comment.make!(comment: "deleted", is_deleted: true)

      expect(Comment.active.map(&:id)).to include(c1.id)
      expect(Comment.active.map(&:id)).not_to include(c2.id)
    end

    it "excludes moderated comments" do
      c1 = Comment.make!(comment: "active")
      c2 = Comment.make!(comment: "moderated", is_moderated: true)

      expect(Comment.active.map(&:id)).to include(c1.id)
      expect(Comment.active.map(&:id)).not_to include(c2.id)
    end
  end
end
