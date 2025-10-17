require "spec_helper"

describe User, "karma and permissions" do
  describe "karma calculation" do
    it "calculates karma from story scores" do
      user = User.make!
      s1 = Story.make!(user_id: user.id, title: "story 1")
      s2 = Story.make!(user_id: user.id, title: "story 2")

      s1.update_column(:upvotes, 10)
      s1.update_column(:downvotes, 2)
      s2.update_column(:upvotes, 5)
      s2.update_column(:downvotes, 1)

      user.karma = user.stories.map(&:score).sum
      expect(user.karma).to eq(12) # (10-2) + (5-1)
    end

    it "calculates karma from comment scores" do
      user = User.make!
      story = Story.make!

      c1 = Comment.make!(user_id: user.id, story_id: story.id, comment: "comment 1")
      c2 = Comment.make!(user_id: user.id, story_id: story.id, comment: "comment 2")

      c1.update_column(:upvotes, 8)
      c1.update_column(:downvotes, 1)
      c2.update_column(:upvotes, 3)
      c2.update_column(:downvotes, 0)

      karma = user.comments.map(&:score).sum
      expect(karma).to eq(10) # (8-1) + (3-0)
    end

    it "calculates average karma" do
      user = User.make!(karma: 100)

      # Create stories and comments
      3.times { Story.make!(user_id: user.id, title: "test") }
      5.times { Comment.make!(user_id: user.id, comment: "test") }

      Keystore.put("user:#{user.id}:stories_submitted", 3)
      Keystore.put("user:#{user.id}:comments_posted", 5)

      avg = user.average_karma
      expect(avg).to eq(12.5) # 100 / (3 + 5)
    end

    it "returns 0 average karma when no activity" do
      user = User.make!(karma: 0)
      expect(user.average_karma).to eq(0)
    end
  end

  describe "permissions based on karma" do
    describe "#can_submit_stories?" do
      it "allows users with karma >= MIN_KARMA_TO_SUBMIT_STORIES" do
        user = User.make!(karma: User::MIN_KARMA_TO_SUBMIT_STORIES)
        expect(user.can_submit_stories?).to eq(true)
      end

      it "blocks users with low karma" do
        user = User.make!(karma: User::MIN_KARMA_TO_SUBMIT_STORIES - 1)
        expect(user.can_submit_stories?).to eq(false)
      end
    end

    describe "#can_offer_suggestions?" do
      it "allows users with sufficient karma and not new" do
        user = User.make!(karma: User::MIN_KARMA_TO_SUGGEST, created_at: 10.days.ago)
        expect(user.can_offer_suggestions?).to eq(true)
      end

      it "blocks new users even with karma" do
        user = User.make!(karma: User::MIN_KARMA_TO_SUGGEST, created_at: Time.now)
        expect(user.can_offer_suggestions?).to eq(false)
      end

      it "blocks users with insufficient karma" do
        user = User.make!(karma: User::MIN_KARMA_TO_SUGGEST - 1, created_at: 10.days.ago)
        expect(user.can_offer_suggestions?).to eq(false)
      end
    end

    describe "#can_downvote?" do
      let(:user) { User.make!(karma: User::MIN_KARMA_TO_DOWNVOTE, created_at: 10.days.ago) }
      let(:new_user) { User.make!(karma: 100, created_at: Time.now) }

      it "allows downvoting stories when downvotable" do
        story = Story.make!(created_at: 1.day.ago)
        story.vote = 0

        expect(user.can_downvote?(story)).to eq(true)
      end

      it "blocks new users from downvoting" do
        story = Story.make!(created_at: 1.day.ago)
        story.vote = 0

        expect(new_user.can_downvote?(story)).to eq(false)
      end

      it "allows downvoting comments with sufficient karma" do
        comment = Comment.make!(created_at: 1.day.ago, comment: "test")

        expect(user.can_downvote?(comment)).to eq(true)
      end

      it "blocks downvoting comments without sufficient karma" do
        low_karma_user = User.make!(karma: 20, created_at: 10.days.ago)
        comment = Comment.make!(created_at: 1.day.ago, comment: "test")

        expect(low_karma_user.can_downvote?(comment)).to eq(false)
      end
    end

    describe "#can_invite?" do
      it "allows users who can submit stories and not banned from inviting" do
        user = User.make!(karma: User::MIN_KARMA_TO_SUBMIT_STORIES)
        expect(user.can_invite?).to eq(true)
      end

      it "blocks users banned from inviting" do
        user = User.make!(karma: 100)
        user.update_column(:disabled_invite_at, Time.now)

        expect(user.can_invite?).to eq(false)
      end

      it "blocks users who can't submit stories" do
        user = User.make!(karma: -10)
        expect(user.can_invite?).to eq(false)
      end
    end
  end

  describe "2FA (TOTP)" do
    it "has no 2FA by default" do
      user = User.make!
      expect(user.has_2fa?).to eq(false)
    end

    it "has 2FA when totp_secret is set" do
      user = User.make!
      user.totp_secret = ROTP::Base32.random
      user.save!

      expect(user.has_2fa?).to eq(true)
    end

    it "can disable 2FA" do
      user = User.make!
      user.totp_secret = ROTP::Base32.random
      user.save!

      user.disable_2fa!
      expect(user.has_2fa?).to eq(false)
    end

    it "authenticates with valid TOTP code" do
      user = User.make!
      secret = ROTP::Base32.random
      user.totp_secret = secret
      user.save!

      totp = ROTP::TOTP.new(secret)
      code = totp.now

      expect(user.authenticate_totp(code)).to be_truthy
    end

    it "rejects invalid TOTP code" do
      user = User.make!
      user.totp_secret = ROTP::Base32.random
      user.save!

      expect(user.authenticate_totp("000000")).to be_falsy
    end
  end

  describe "session management" do
    it "creates session token on creation" do
      user = User.make!
      expect(user.session_token).to be_present
      expect(user.session_token.length).to be >= 20
    end

    it "creates rss token on creation" do
      user = User.make!
      expect(user.rss_token).to be_present
    end

    it "creates mailing list token on creation" do
      user = User.make!
      expect(user.mailing_list_token).to be_present
    end

    it "regenerates session token when blank" do
      user = User.make!
      old_token = user.session_token

      user.session_token = nil
      user.save!

      expect(user.session_token).to be_present
      expect(user.session_token).not_to eq(old_token)
    end
  end

  describe "user states" do
    describe "#is_new?" do
      it "returns true for users within NEW_USER_DAYS" do
        user = User.make!(created_at: (User::NEW_USER_DAYS - 1).days.ago)
        expect(user.is_new?).to eq(true)
      end

      it "returns false for old users" do
        user = User.make!(created_at: (User::NEW_USER_DAYS + 1).days.ago)
        expect(user.is_new?).to eq(false)
      end
    end

    describe "#is_active?" do
      it "returns true for normal users" do
        user = User.make!
        expect(user.is_active?).to eq(true)
      end

      it "returns false for banned users" do
        user = User.make!
        user.update_column(:banned_at, Time.now)
        expect(user.is_active?).to eq(false)
      end

      it "returns false for deleted users" do
        user = User.make!
        user.update_column(:deleted_at, Time.now)
        expect(user.is_active?).to eq(false)
      end
    end

    describe "#banned_from_inviting?" do
      it "returns false when not disabled" do
        user = User.make!
        expect(user.banned_from_inviting?).to eq(false)
      end

      it "returns true when disabled" do
        user = User.make!
        user.update_column(:disabled_invite_at, Time.now)
        expect(user.banned_from_inviting?).to eq(true)
      end
    end
  end

  describe "moderation actions" do
    let(:moderator) { User.make!(is_moderator: true) }

    describe "#ban_by_user_for_reason!" do
      it "bans user and creates moderation log" do
        user = User.make!
        initial_mod_count = Moderation.count

        user.ban_by_user_for_reason!(moderator, "spam")

        expect(user.banned_at).to be_present
        expect(user.banned_by_user_id).to eq(moderator.id)
        expect(user.banned_reason).to eq("spam")
        expect(Moderation.count).to eq(initial_mod_count + 1)
      end
    end

    describe "#unban_by_user!" do
      it "unbans user and creates moderation log" do
        user = User.make!
        user.update_columns(banned_at: Time.now, banned_reason: "test")

        initial_mod_count = Moderation.count
        user.unban_by_user!(moderator)

        expect(user.banned_at).to be_nil
        expect(user.banned_reason).to be_nil
        expect(Moderation.count).to eq(initial_mod_count + 1)
      end
    end

    describe "#disable_invite_by_user_for_reason!" do
      it "disables invites and creates moderation log" do
        user = User.make!
        initial_mod_count = Moderation.count

        user.disable_invite_by_user_for_reason!(moderator, "abuse")

        expect(user.disabled_invite_at).to be_present
        expect(user.disabled_invite_by_user_id).to eq(moderator.id)
        expect(user.disabled_invite_reason).to eq("abuse")
        expect(Moderation.count).to eq(initial_mod_count + 1)
      end

      it "sends notification message" do
        user = User.make!
        initial_msg_count = Message.count

        user.disable_invite_by_user_for_reason!(moderator, "abuse")

        expect(Message.count).to eq(initial_msg_count + 1)
      end
    end

    describe "#enable_invite_by_user!" do
      it "re-enables invites and creates moderation log" do
        user = User.make!
        user.update_columns(disabled_invite_at: Time.now, disabled_invite_reason: "test")

        initial_mod_count = Moderation.count
        user.enable_invite_by_user!(moderator)

        expect(user.disabled_invite_at).to be_nil
        expect(user.disabled_invite_reason).to be_nil
        expect(Moderation.count).to eq(initial_mod_count + 1)
      end
    end

    describe "#grant_moderatorship_by_user!" do
      it "grants moderator status" do
        user = User.make!
        admin = User.make!(is_admin: true)

        user.grant_moderatorship_by_user!(admin)

        expect(user.is_moderator).to eq(true)
      end

      it "creates moderation log" do
        user = User.make!
        admin = User.make!(is_admin: true)
        initial_mod_count = Moderation.count

        user.grant_moderatorship_by_user!(admin)

        # Creates moderation logs for both granting moderator AND creating Sysop hat
        expect(Moderation.count).to eq(initial_mod_count + 2)
      end

      it "creates Sysop hat" do
        user = User.make!
        admin = User.make!(is_admin: true)
        initial_hat_count = Hat.count

        user.grant_moderatorship_by_user!(admin)

        expect(Hat.count).to eq(initial_hat_count + 1)
        expect(user.hats.last.hat).to eq("Sysop")
      end
    end
  end

  describe "user deletion" do
    describe "#delete!" do
      it "soft deletes user" do
        user = User.make!
        user.delete!

        expect(user.deleted_at).to be_present
      end

      it "deletes all comments" do
        user = User.make!
        comment = Comment.make!(user_id: user.id, comment: "test")

        user.delete!
        comment.reload

        expect(comment.is_deleted).to eq(true)
      end

      it "marks sent messages as deleted" do
        user = User.make!
        recipient = User.make!
        message = Message.create!(
          author_user_id: user.id,
          recipient_user_id: recipient.id,
          subject: "test",
          body: "test"
        )

        user.delete!
        message.reload

        expect(message.deleted_by_author).to eq(true)
      end

      it "marks received messages as deleted" do
        sender = User.make!
        user = User.make!
        message = Message.create!(
          author_user_id: sender.id,
          recipient_user_id: user.id,
          subject: "test",
          body: "test"
        )

        user.delete!
        message.reload

        expect(message.deleted_by_recipient).to eq(true)
      end

      it "destroys invitations" do
        user = User.make!
        Invitation.create!(user_id: user.id, email: "test@example.com", code: "testcode")

        user.delete!

        expect(user.invitations.count).to eq(0)
      end

      it "regenerates session token" do
        user = User.make!
        old_token = user.session_token

        user.delete!

        expect(user.session_token).not_to eq(old_token)
      end
    end

    describe "#undelete!" do
      it "restores deleted user" do
        user = User.make!
        user.delete!

        user.undelete!

        expect(user.deleted_at).to be_nil
      end

      it "undeletes comments" do
        user = User.make!
        comment = Comment.make!(user_id: user.id, comment: "test")
        user.delete!

        user.undelete!
        comment.reload

        expect(comment.is_deleted).to eq(false)
      end
    end
  end

  describe "utility methods" do
    describe "#avatar_url" do
      it "generates gravatar URL" do
        user = User.make!(email: "test@example.com")
        url = user.avatar_url

        expect(url).to include("gravatar.com")
        expect(url).to include("avatar")
      end

      it "accepts size parameter" do
        user = User.make!
        url = user.avatar_url(200)

        expect(url).to include("s=200")
      end
    end

    describe "#to_param" do
      it "uses username as param" do
        user = User.make!(username: "testuser")
        expect(user.to_param).to eq("testuser")
      end
    end

    describe "#linkified_about" do
      it "converts markdown in about" do
        user = User.make!(about: "**Bold text**")
        html = user.linkified_about

        expect(html).to include("<strong>")
      end
    end

    describe "message counts" do
      it "tracks unread messages" do
        user = User.make!
        Keystore.put("user:#{user.id}:unread_messages", 5)

        expect(user.unread_message_count).to eq(5)
      end

      it "updates unread message count" do
        sender = User.make!
        user = User.make!

        3.times do
          Message.create!(
            author_user_id: sender.id,
            recipient_user_id: user.id,
            subject: "test",
            body: "test",
            has_been_read: false
          )
        end

        user.update_unread_message_count!
        expect(user.unread_message_count).to eq(3)
      end
    end

    describe "activity counts" do
      it "tracks stories submitted" do
        user = User.make!
        Keystore.put("user:#{user.id}:stories_submitted", 10)

        expect(user.stories_submitted_count).to eq(10)
      end

      it "tracks comments posted" do
        user = User.make!
        Keystore.put("user:#{user.id}:comments_posted", 25)

        expect(user.comments_posted_count).to eq(25)
      end

      it "updates comments posted count" do
        user = User.make!
        story = Story.make!

        3.times { Comment.make!(user_id: user.id, story_id: story.id, comment: "test") }

        user.update_comments_posted_count!
        expect(user.comments_posted_count).to be >= 3
      end
    end
  end

  describe ".active scope" do
    it "excludes banned users" do
      active = User.make!
      banned = User.make!
      banned.update_column(:banned_at, Time.now)

      expect(User.active).to include(active)
      expect(User.active).not_to include(banned)
    end

    it "excludes deleted users" do
      active = User.make!
      deleted = User.make!
      deleted.update_column(:deleted_at, Time.now)

      expect(User.active).to include(active)
      expect(User.active).not_to include(deleted)
    end
  end
end
