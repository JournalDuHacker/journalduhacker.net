require "spec_helper"

describe HiddenStory do
  describe "associations" do
    it "belongs to user" do
      user = User.make!
      story = Story.make!
      hidden = HiddenStory.create!(user_id: user.id, story_id: story.id)

      expect(hidden.user).to eq(user)
    end

    it "belongs to story" do
      user = User.make!
      story = Story.make!
      hidden = HiddenStory.create!(user_id: user.id, story_id: story.id)

      expect(hidden.story).to eq(story)
    end
  end

  describe "validations" do
    it "requires user_id" do
      story = Story.make!
      hidden = HiddenStory.new(story_id: story.id)

      expect(hidden.valid?).to eq(false)
      expect(hidden.errors[:user_id]).to be_present
    end

    it "requires story_id" do
      user = User.make!
      hidden = HiddenStory.new(user_id: user.id)

      expect(hidden.valid?).to eq(false)
      expect(hidden.errors[:story_id]).to be_present
    end

    it "creates with valid user and story" do
      user = User.make!
      story = Story.make!
      hidden = HiddenStory.create!(user_id: user.id, story_id: story.id)

      expect(hidden).to be_persisted
    end
  end

  describe ".hide_story_for_user" do
    it "creates hidden story record" do
      user = User.make!
      story = Story.make!

      HiddenStory.hide_story_for_user(story.id, user.id)

      hidden = HiddenStory.where(user_id: user.id, story_id: story.id).first
      expect(hidden).to be_present
      expect(hidden).to be_persisted
    end

    it "is idempotent - doesn't create duplicate" do
      user = User.make!
      story = Story.make!

      HiddenStory.hide_story_for_user(story.id, user.id)
      initial_count = HiddenStory.where(user_id: user.id, story_id: story.id).count

      HiddenStory.hide_story_for_user(story.id, user.id)
      final_count = HiddenStory.where(user_id: user.id, story_id: story.id).count

      expect(final_count).to eq(initial_count)
      expect(final_count).to eq(1)
    end

    it "allows different users to hide same story" do
      user1 = User.make!
      user2 = User.make!
      story = Story.make!

      HiddenStory.hide_story_for_user(story.id, user1.id)
      HiddenStory.hide_story_for_user(story.id, user2.id)

      expect(HiddenStory.where(story_id: story.id).count).to eq(2)
    end

    it "allows same user to hide multiple stories" do
      user = User.make!
      story1 = Story.make!
      story2 = Story.make!

      HiddenStory.hide_story_for_user(story1.id, user.id)
      HiddenStory.hide_story_for_user(story2.id, user.id)

      expect(HiddenStory.where(user_id: user.id).count).to eq(2)
    end
  end
end
