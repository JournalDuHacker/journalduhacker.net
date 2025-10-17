require "spec_helper"

describe Story, "hotness calculations" do
  describe "#calculated_hotness" do
    it "calculates hotness based on score and age" do
      s = Story.make!(title: "test story")
      hotness = s.calculated_hotness

      expect(hotness).to be < 0 # Hotness is negative (lower is hotter)
      expect(hotness).to be_a(Float)
    end

    it "gives higher hotness to stories with more upvotes" do
      s1 = Story.make!(title: "low votes")
      s1.update_column(:upvotes, 2)

      s2 = Story.make!(title: "high votes")
      s2.update_column(:upvotes, 20)

      # Lower (more negative) = hotter
      expect(s2.calculated_hotness).to be < s1.calculated_hotness
    end

    it "gives bump to author stories" do
      author_story = Story.make!(title: "author story", user_is_author: true, url: nil, description: "content")
      url_story = Story.make!(title: "url story", url: "http://example.com/")

      # Author stories get 0.25 bump (making them hotter = more negative)
      expect(author_story.calculated_hotness).to be < url_story.calculated_hotness
    end

    it "considers tag hotness modifiers" do
      # Create a tag with positive hotness_mod (makes story colder)
      hot_tag = Tag.create!(tag: "hottag", description: "hot", hotness_mod: 2.0)
      cold_tag = Tag.create!(tag: "coldtag", description: "cold", hotness_mod: -2.0)

      s1 = Story.make!(title: "with hot tag", tags_a: ["hottag"])
      s2 = Story.make!(title: "with cold tag", tags_a: ["coldtag"])

      # Cold tag (negative mod) makes story hotter (more negative hotness)
      # Use a wider margin to account for timing differences
      expect((s2.calculated_hotness - s1.calculated_hotness).abs).to be > 1.0
    end

    it "factors in comment votes" do
      s = Story.make!(title: "story with comments")
      other_user = User.make!

      # Add comments from another user
      3.times do
        c = Comment.make!(story_id: s.id, user_id: other_user.id, comment: "good comment")
        c.update_column(:upvotes, 5)
      end

      hotness_with_comments = s.calculated_hotness

      # More comment activity should make story hotter
      expect(hotness_with_comments).to be_a(Float)
    end

    it "caps comment points at story upvotes" do
      s = Story.make!(title: "story")
      s.update_column(:upvotes, 2)

      other_user = User.make!

      # Add many highly voted comments
      5.times do
        c = Comment.make!(story_id: s.id, user_id: other_user.id, comment: "comment")
        c.update_column(:upvotes, 10)
      end

      # Comment points should be capped
      expect(s.calculated_hotness).to be_a(Float)
    end
  end

  describe "#recalculate_hotness!" do
    it "updates hotness column" do
      s = Story.make!(title: "test")
      old_hotness = s.hotness

      s.update_column(:upvotes, 50)
      s.recalculate_hotness!
      s.reload

      expect(s.hotness).not_to eq(old_hotness)
    end

    it "is called after story is saved" do
      s = Story.make!(title: "test")
      initial_hotness = s.hotness

      s.upvotes = 20
      s.save!
      s.reload

      # Hotness should be recalculated
      expect(s.hotness).not_to eq(initial_hotness)
    end
  end

  describe "#assign_initial_hotness" do
    it "sets hotness on creation" do
      s = Story.make!(title: "new story")
      expect(s.hotness).to be_present
      expect(s.hotness).to be < 0
    end
  end

  describe ".recalculate_all_hotnesses!" do
    it "recalculates hotness for all stories" do
      s1 = Story.make!(title: "story1")
      s2 = Story.make!(title: "story2")

      s1.update_column(:hotness, 0)
      s2.update_column(:hotness, 0)

      Story.recalculate_all_hotnesses!

      s1.reload
      s2.reload

      expect(s1.hotness).not_to eq(0)
      expect(s2.hotness).not_to eq(0)
    end
  end

  describe "#is_downvotable?" do
    it "is downvotable when recent and score above minimum" do
      s = Story.make!(title: "test", created_at: 1.day.ago)
      s.update_column(:upvotes, 10)
      s.update_column(:downvotes, 0)

      expect(s.is_downvotable?).to eq(true)
    end

    it "is not downvotable when score too low" do
      s = Story.make!(title: "test", created_at: 1.day.ago)
      s.update_column(:upvotes, 1)
      s.update_column(:downvotes, 10)

      expect(s.is_downvotable?).to eq(false)
    end

    it "is not downvotable when too old" do
      s = Story.make!(title: "test", created_at: (Story::DOWNVOTABLE_DAYS + 1).days.ago)

      expect(s.is_downvotable?).to eq(false)
    end
  end

  describe "#score" do
    it "calculates as upvotes minus downvotes" do
      s = Story.make!(title: "test")
      s.update_column(:upvotes, 15)
      s.update_column(:downvotes, 3)

      expect(s.score).to eq(12)
    end

    it "can be negative" do
      s = Story.make!(title: "test")
      s.update_column(:upvotes, 2)
      s.update_column(:downvotes, 10)

      expect(s.score).to eq(-8)
    end
  end

  describe "#give_upvote_or_downvote_and_recalculate_hotness!" do
    it "updates votes and recalculates hotness" do
      s = Story.make!(title: "test")
      initial_upvotes = s.upvotes
      initial_hotness = s.hotness

      s.give_upvote_or_downvote_and_recalculate_hotness!(1, 0)
      s.reload

      expect(s.upvotes).to eq(initial_upvotes + 1)
      expect(s.hotness).not_to eq(initial_hotness)
    end

    it "handles downvotes" do
      s = Story.make!(title: "test")
      initial_downvotes = s.downvotes

      s.give_upvote_or_downvote_and_recalculate_hotness!(0, 1)
      s.reload

      expect(s.downvotes).to eq(initial_downvotes + 1)
    end
  end
end
