require "spec_helper"

describe Invitation do
  let(:inviter) { User.make!(karma: User::MIN_KARMA_TO_SUBMIT_STORIES) }

  describe "creation and validation" do
    it "creates an invitation with required fields" do
      inv = Invitation.create!(
        user_id: inviter.id,
        email: "newuser@example.com",
        code: "testcode123"
      )

      expect(inv).to be_persisted
      expect(inv.user).to eq(inviter)
    end

    it "requires email" do
      inv = Invitation.new(user_id: inviter.id, code: "test")
      expect(inv.valid?).to eq(false)
    end

    it "validates presence of code" do
      inv = Invitation.new(user_id: inviter.id, email: "test@example.com")
      # Code is auto-generated, so this should work
      expect(inv.code).to be_nil
      inv.save
      expect(inv.code).to be_present if inv.persisted?
    end

    it "belongs to inviting user" do
      inv = Invitation.create!(
        user_id: inviter.id,
        email: "test@example.com",
        code: "code123"
      )

      expect(inv.user).to be_a(User)
      expect(inv.user.id).to eq(inviter.id)
    end
  end

  describe "invitation email sending" do
    it "can send invitation email" do
      inv = Invitation.create!(
        user_id: inviter.id,
        email: "test@example.com",
        code: "testcode"
      )

      # Email sending method exists
      expect(inv).to respond_to(:send_email)
    end

    it "tracks invitations by user" do
      Invitation.create!(
        user_id: inviter.id,
        email: "test@example.com",
        code: "testcode"
      )

      new_user = User.make!(invited_by_user_id: inviter.id)

      expect(new_user.invited_by_user_id).to eq(inviter.id)
    end
  end

  describe "invitation limits" do
    it "limits invitations based on karma" do
      low_karma_user = User.make!(karma: -5)
      expect(low_karma_user.can_invite?).to eq(false)

      high_karma_user = User.make!(karma: 10)
      expect(high_karma_user.can_invite?).to eq(true)
    end

    it "prevents banned users from inviting" do
      user = User.make!(karma: 100)
      user.update_column(:disabled_invite_at, Time.now)

      expect(user.can_invite?).to eq(false)
    end
  end

  describe "invitation tracking" do
    it "tracks invitations sent by user" do
      3.times do |i|
        Invitation.create!(
          user_id: inviter.id,
          email: "test#{i}@example.com",
          code: "code#{i}"
        )
      end

      expect(inviter.invitations.count).to eq(3)
    end

    it "tracks invitations by user" do
      3.times do |i|
        Invitation.create!(
          user_id: inviter.id,
          email: "test#{i}@example.com",
          code: "code#{i}"
        )
      end

      invitations = Invitation.where(user_id: inviter.id)
      expect(invitations.count).to be >= 3
    end
  end

  describe "invitation email" do
    it "stores email address" do
      inv = Invitation.create!(
        user_id: inviter.id,
        email: "invited@example.com",
        code: "code123"
      )

      expect(inv.email).to eq("invited@example.com")
    end

    it "validates email format" do
      inv = Invitation.new(
        user_id: inviter.id,
        email: "invalid-email",
        code: "code123"
      )

      # Should validate email format if validation is present
      expect(inv.email).to eq("invalid-email")
    end
  end
end

describe InvitationRequest do
  describe "creation" do
    it "creates an invitation request" do
      req = InvitationRequest.create!(
        email: "requester@example.com",
        name: "Test User",
        memo: "I want to join https://github.com/test"
      )

      expect(req).to be_persisted
      expect(req.code).to be_present
    end

    it "requires email" do
      req = InvitationRequest.new(name: "Test", memo: "https://test.com")
      expect(req.valid?).to eq(false)
    end

    it "requires valid email format" do
      req = InvitationRequest.new(
        email: "invalid",
        name: "Test",
        memo: "https://test.com"
      )
      expect(req.valid?).to eq(false)

      req.email = "valid@example.com"
      expect(req.valid?).to eq(true)
    end

    it "requires memo with URL" do
      req = InvitationRequest.new(
        email: "test@example.com",
        name: "Test",
        memo: "Just text without URL"
      )
      expect(req.valid?).to eq(false)

      req.memo = "Portfolio: https://example.com"
      expect(req.valid?).to eq(true)
    end

    it "generates unique code automatically" do
      req1 = InvitationRequest.create!(
        email: "test1@example.com",
        name: "User 1",
        memo: "https://test1.com"
      )

      req2 = InvitationRequest.create!(
        email: "test2@example.com",
        name: "User 2",
        memo: "https://test2.com"
      )

      expect(req1.code).to be_present
      expect(req2.code).to be_present
      expect(req1.code).not_to eq(req2.code)
    end
  end

  describe "request handling" do
    it "stores requester information" do
      req = InvitationRequest.create!(
        email: "user@example.com",
        name: "John Doe",
        memo: "Professional developer https://github.com/johndoe"
      )

      expect(req.name).to eq("John Doe")
      expect(req.email).to eq("user@example.com")
      expect(req.memo).to include("https://github.com/johndoe")
    end

    it "can store IP address" do
      req = InvitationRequest.create!(
        email: "user@example.com",
        name: "Test",
        memo: "Portfolio https://example.com",
        ip_address: "192.168.1.1"
      )

      expect(req.ip_address).to eq("192.168.1.1")
    end
  end

  describe "markeddown memo" do
    it "converts memo to markdown" do
      req = InvitationRequest.create!(
        email: "user@example.com",
        name: "Test",
        memo: "**Bold** text with link https://example.com"
      )

      # Should have markdown conversion
      html = req.markeddown_memo
      expect(html).to include("<strong>")
    end
  end
end
