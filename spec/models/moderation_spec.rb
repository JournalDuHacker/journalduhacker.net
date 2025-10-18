require "spec_helper"

describe Moderation do
  let(:moderator) { User.make!(is_moderator: true) }
  let(:user) { User.make! }

  describe "creation and associations" do
    it "creates a moderation log" do
      mod = Moderation.create!(
        moderator_user_id: moderator.id,
        action: "Test action",
        reason: "Testing"
      )

      expect(mod).to be_persisted
      expect(mod.moderator).to eq(moderator)
    end

    it "belongs to moderator user" do
      mod = Moderation.create!(
        moderator_user_id: moderator.id,
        action: "Test"
      )

      expect(mod.moderator).to be_a(User)
      expect(mod.moderator.is_moderator?).to eq(true)
    end

    it "can be associated with a story" do
      story = Story.make!
      mod = Moderation.create!(
        moderator_user_id: moderator.id,
        story_id: story.id,
        action: "Edited story"
      )

      expect(mod.story).to eq(story)
    end

    it "can be associated with a comment" do
      comment = Comment.make!(comment: "test")
      mod = Moderation.create!(
        moderator_user_id: moderator.id,
        comment_id: comment.id,
        action: "Deleted comment"
      )

      expect(mod.comment).to eq(comment)
    end

    it "can be associated with a user" do
      mod = Moderation.create!(
        moderator_user_id: moderator.id,
        user_id: user.id,
        action: "Banned user"
      )

      expect(mod.user).to eq(user)
    end

    it "tracks tag-related actions in action field" do
      Tag.create!(tag: "test", description: "Test tag")
      mod = Moderation.create!(
        moderator_user_id: moderator.id,
        action: "Created tag: test"
      )

      expect(mod.action).to include("tag")
      expect(mod.action).to include("test")
    end
  end

  describe "moderation actions tracking" do
    it "logs story edits" do
      story = Story.make!(user_id: user.id, title: "Original")

      story.editor = moderator
      story.moderation_reason = "Improved title"
      story.title = "Better Title"
      story.save!

      mod = Moderation.where(story_id: story.id).last
      expect(mod).to be_present
      expect(mod.moderator_user_id).to eq(moderator.id)
      expect(mod.action).to include("title")
    end

    it "logs story deletions" do
      story = Story.make!(user_id: user.id)

      story.editor = moderator
      story.moderation_reason = "Spam"
      story.is_expired = true
      story.save!

      mod = Moderation.where(story_id: story.id).last
      expect(mod).to be_present
      expect(mod.reason).to eq("Spam")
    end

    it "logs comment deletions by moderator" do
      comment = Comment.make!(user_id: user.id, comment: "test")

      comment.delete_for_user(moderator, "Off-topic")

      mod = Moderation.where(comment_id: comment.id).last
      expect(mod).to be_present
      expect(mod.moderator_user_id).to eq(moderator.id)
      expect(mod.reason).to eq("Off-topic")
    end

    it "logs user bans" do
      user.ban_by_user_for_reason!(moderator, "Spam account")

      mod = Moderation.where(user_id: user.id, action: "Banned").last
      expect(mod).to be_present
      expect(mod.moderator_user_id).to eq(moderator.id)
      expect(mod.reason).to eq("Spam account")
    end

    it "logs user unbans" do
      user.update_column(:banned_at, Time.now)
      user.unban_by_user!(moderator)

      mod = Moderation.where(user_id: user.id, action: "Unbanned").last
      expect(mod).to be_present
      expect(mod.moderator_user_id).to eq(moderator.id)
    end

    it "logs invitation privilege revocation" do
      user.disable_invite_by_user_for_reason!(moderator, "Invite abuse")

      mod = Moderation.where(user_id: user.id).last
      expect(mod).to be_present
      expect(mod.action).to include("Disabled invitations")
      expect(mod.reason).to eq("Invite abuse")
    end

    it "logs invitation privilege restoration" do
      user.update_column(:disabled_invite_at, Time.now)
      user.enable_invite_by_user!(moderator)

      mod = Moderation.where(user_id: user.id).last
      expect(mod).to be_present
      expect(mod.action).to include("Enabled invitations")
    end

    it "logs moderator grants" do
      new_mod = User.make!
      new_mod.grant_moderatorship_by_user!(moderator)

      mod = Moderation.where(user_id: new_mod.id).last
      expect(mod).to be_present
      expect(mod.action).to include("Granted hat")
    end
  end

  describe "suggestion-based moderations" do
    it "marks moderation as from suggestions" do
      story = Story.make!

      story.editing_from_suggestions = true
      story.editor = nil
      story.moderation_reason = "Automatically changed from user suggestions"
      story.title = "New Title"
      story.save!

      mod = Moderation.where(story_id: story.id).last
      expect(mod.is_from_suggestions).to eq(true)
    end
  end

  describe "moderation history" do
    it "provides complete moderation trail for story" do
      story = Story.make!(user_id: user.id, title: "Original")

      # First edit
      story.editor = moderator
      story.moderation_reason = "First edit"
      story.title = "Edit 1"
      story.save!

      # Second edit
      story.editor = moderator
      story.moderation_reason = "Second edit"
      story.title = "Edit 2"
      story.save!

      mods = Moderation.where(story_id: story.id)
      expect(mods.count).to be >= 2
    end

    it "provides complete moderation trail for user" do
      # Multiple actions on same user
      user.disable_invite_by_user_for_reason!(moderator, "Reason 1")
      user.enable_invite_by_user!(moderator)

      mods = Moderation.where(user_id: user.id)
      expect(mods.count).to be >= 2
    end
  end

  describe "moderation queries" do
    before do
      # Create various moderation logs
      Moderation.create!(
        moderator_user_id: moderator.id,
        action: "Test 1",
        created_at: 2.days.ago
      )
      Moderation.create!(
        moderator_user_id: moderator.id,
        action: "Test 2",
        created_at: 1.day.ago
      )
    end

    it "orders by most recent first" do
      mods = Moderation.order("id DESC").limit(2)
      expect(mods.first.created_at).to be > mods.last.created_at
    end

    it "can filter by moderator" do
      other_mod = User.make!(is_moderator: true)
      Moderation.create!(
        moderator_user_id: other_mod.id,
        action: "Other mod action"
      )

      mods = Moderation.where(moderator_user_id: moderator.id)
      expect(mods.all? { |m| m.moderator_user_id == moderator.id }).to eq(true)
    end

    it "can filter by action type" do
      Moderation.create!(
        moderator_user_id: moderator.id,
        action: "Banned",
        user_id: user.id
      )

      banned_mods = Moderation.where("action LIKE ?", "%Banned%")
      expect(banned_mods.count).to be > 0
    end
  end
end
