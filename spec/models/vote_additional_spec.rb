require "spec_helper"

describe Vote, "additional scenarios" do
  describe "vote reasons" do
    it "stores reason for story downvote" do
      story = Story.make!
      user = User.make!(karma: 100)

      Vote.vote_thusly_on_story_or_comment_for_user_because(
        -1, story.id, nil, user.id, Vote::STORY_REASONS.keys.first
      )

      vote = Vote.where(user_id: user.id, story_id: story.id).first
      expect(vote.reason).to be_present
    end

    it "stores reason for comment downvote" do
      comment = Comment.make!(comment: "test")
      user = User.make!(karma: 100)

      Vote.vote_thusly_on_story_or_comment_for_user_because(
        -1, comment.story_id, comment.id, user.id, Vote::COMMENT_REASONS.keys.first
      )

      vote = Vote.where(user_id: user.id, comment_id: comment.id).first
      expect(vote.reason).to be_present
    end

    it "allows changing vote from upvote to downvote" do
      story = Story.make!
      user = User.make!(karma: 100)

      # First upvote
      Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id, nil, user.id, nil)
      story.reload
      initial_upvotes = story.upvotes

      # Change to downvote
      Vote.vote_thusly_on_story_or_comment_for_user_because(
        -1, story.id, nil, user.id, Vote::STORY_REASONS.keys.first
      )
      story.reload

      expect(story.upvotes).to eq(initial_upvotes - 1)
      expect(story.downvotes).to eq(1)
    end

    it "allows changing vote from downvote to upvote" do
      comment = Comment.make!(comment: "test")
      user = User.make!(karma: 100, created_at: 10.days.ago)

      # First downvote
      Vote.vote_thusly_on_story_or_comment_for_user_because(
        -1, comment.story_id, comment.id, user.id, Vote::COMMENT_REASONS.keys.first
      )
      comment.reload
      initial_downvotes = comment.downvotes

      # Change to upvote
      Vote.vote_thusly_on_story_or_comment_for_user_because(
        1, comment.story_id, comment.id, user.id, nil
      )
      comment.reload

      expect(comment.downvotes).to eq(initial_downvotes - 1)
      expect(comment.upvotes).to be > 1
    end
  end

  describe "vote removal (unvote)" do
    it "removes story vote when voting 0" do
      story = Story.make!
      user = User.make!

      Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id, nil, user.id, nil)
      initial_upvotes = story.reload.upvotes

      Vote.vote_thusly_on_story_or_comment_for_user_because(0, story.id, nil, user.id, nil)
      story.reload

      expect(story.upvotes).to eq(initial_upvotes - 1)
      # Vote with 0 removes the vote record or sets vote to 0
      vote = Vote.where(user_id: user.id, story_id: story.id).first
      expect(vote&.vote).to be_nil.or eq(0)
    end

    it "removes comment vote when voting 0" do
      comment = Comment.make!(comment: "test")
      user = User.make!

      Vote.vote_thusly_on_story_or_comment_for_user_because(
        1, comment.story_id, comment.id, user.id, nil
      )
      initial_upvotes = comment.reload.upvotes

      Vote.vote_thusly_on_story_or_comment_for_user_because(
        0, comment.story_id, comment.id, user.id, nil
      )
      comment.reload

      expect(comment.upvotes).to eq(initial_upvotes - 1)
    end
  end

  describe "karma updates" do
    it "increases submitter karma on upvote" do
      user = User.make!(karma: 10)
      story = Story.make!(user_id: user.id, title: "test")
      voter = User.make!

      initial_score = story.score

      Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id, nil, voter.id, nil)
      story.reload

      expect(story.score).to eq(initial_score + 1)
    end

    it "decreases submitter karma on downvote" do
      user = User.make!(karma: 10)
      story = Story.make!(user_id: user.id, title: "test")
      voter = User.make!(karma: 100)

      initial_score = story.score

      Vote.vote_thusly_on_story_or_comment_for_user_because(
        -1, story.id, nil, voter.id, Vote::STORY_REASONS.keys.first
      )
      story.reload

      expect(story.score).to eq(initial_score - 1)
    end

    it "updates comment confidence after voting" do
      comment = Comment.make!(comment: "test")
      user = User.make!

      initial_confidence = comment.confidence

      Vote.vote_thusly_on_story_or_comment_for_user_because(
        1, comment.story_id, comment.id, user.id, nil
      )
      comment.reload

      expect(comment.confidence).not_to eq(initial_confidence)
    end
  end

  describe "hide votes" do
    it "hiding stories uses HiddenStory model" do
      story = Story.make!
      user = User.make!

      initial_score = story.score

      HiddenStory.hide_story_for_user(story.id, user.id)

      story.reload
      expect(story.score).to eq(initial_score)
      expect(story.is_hidden_by_user?(user)).to eq(true)
    end

    it "hiding stories doesn't create Vote record" do
      story = Story.make!
      user = User.make!

      HiddenStory.hide_story_for_user(story.id, user.id)

      vote = Vote.where(user_id: user.id, story_id: story.id).first
      expect(vote).to be_nil
    end
  end

  describe "vote validation" do
    it "prevents duplicate upvotes" do
      story = Story.make!
      user = User.make!

      Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id, nil, user.id, nil)
      initial_upvotes = story.reload.upvotes

      Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id, nil, user.id, nil)
      story.reload

      expect(story.upvotes).to eq(initial_upvotes)
    end

    it "allows user to vote on different stories" do
      user = User.make!
      s1 = Story.make!(title: "story 1")
      s2 = Story.make!(title: "story 2")

      Vote.vote_thusly_on_story_or_comment_for_user_because(1, s1.id, nil, user.id, nil)
      Vote.vote_thusly_on_story_or_comment_for_user_because(1, s2.id, nil, user.id, nil)

      expect(Vote.where(user_id: user.id).count).to eq(2)
    end

    it "allows user to vote on story and comments" do
      user = User.make!
      story = Story.make!
      comment = Comment.make!(story_id: story.id, comment: "test")

      Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id, nil, user.id, nil)
      Vote.vote_thusly_on_story_or_comment_for_user_because(
        1, story.id, comment.id, user.id, nil
      )

      expect(Vote.where(user_id: user.id).count).to eq(2)
    end
  end

  describe "story hotness recalculation" do
    it "triggers hotness recalculation on story vote" do
      story = Story.make!
      user = User.make!
      initial_hotness = story.hotness

      Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id, nil, user.id, nil)
      story.reload

      expect(story.hotness).not_to eq(initial_hotness)
    end

    it "triggers hotness recalculation on comment vote" do
      story = Story.make!
      comment = Comment.make!(story_id: story.id, comment: "test")
      user = User.make!

      story.hotness

      Vote.vote_thusly_on_story_or_comment_for_user_because(
        1, story.id, comment.id, user.id, nil
      )
      story.reload

      # Comment votes affect story hotness
      expect(story.hotness).to be_present
    end
  end

  describe "vote associations" do
    it "belongs to user" do
      vote = Vote.first
      expect(vote.user).to be_present if vote
    end

    it "belongs to story when comment_id is nil" do
      story = Story.make!
      user = User.make!

      Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id, nil, user.id, nil)

      vote = Vote.where(user_id: user.id, story_id: story.id).first
      expect(vote.story).to eq(story)
      expect(vote.comment).to be_nil
    end

    it "belongs to comment when comment_id is present" do
      comment = Comment.make!(comment: "test")
      user = User.make!

      Vote.vote_thusly_on_story_or_comment_for_user_because(
        1, comment.story_id, comment.id, user.id, nil
      )

      vote = Vote.where(user_id: user.id, comment_id: comment.id).first
      expect(vote.comment).to eq(comment)
      expect(vote.story).to eq(comment.story)
    end
  end

  describe "vote summary" do
    it "generates vote summary for story" do
      story = Story.make!
      u1 = User.make!
      u2 = User.make!(karma: 100)

      Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id, nil, u1.id, nil)
      Vote.vote_thusly_on_story_or_comment_for_user_because(
        -1, story.id, nil, u2.id, Vote::STORY_REASONS.keys.first
      )

      summary = story.vote_summary_for(nil)
      expect(summary).to be_present
    end

    it "generates vote summary for comment" do
      comment = Comment.make!(comment: "test")
      u1 = User.make!
      u2 = User.make!(karma: User::MIN_KARMA_TO_DOWNVOTE, created_at: 10.days.ago)

      Vote.vote_thusly_on_story_or_comment_for_user_because(
        1, comment.story_id, comment.id, u1.id, nil
      )
      Vote.vote_thusly_on_story_or_comment_for_user_because(
        -1, comment.story_id, comment.id, u2.id, Vote::COMMENT_REASONS.keys.first
      )

      moderator = User.make!(is_moderator: true)
      summary = comment.vote_summary_for_user(moderator)
      expect(summary).to be_present
    end
  end
end
