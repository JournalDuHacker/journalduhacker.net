require "spec_helper"

describe HatRequest do
  let(:user) { User.make! }
  let(:moderator) { User.make!(is_moderator: true) }

  describe "creation and validation" do
    it "creates a hat request with required fields" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://github.com/username",
        comment: "I am a developer"
      )

      expect(req).to be_persisted
      expect(req.user).to eq(user)
    end

    it "requires user" do
      req = HatRequest.new(
        hat: "Developer",
        link: "https://example.com",
        comment: "Test"
      )

      expect(req.valid?).to eq(false)
      expect(req.errors[:user]).to be_present
    end

    it "requires hat" do
      req = HatRequest.new(
        user_id: user.id,
        link: "https://example.com",
        comment: "Test"
      )

      expect(req.valid?).to eq(false)
      expect(req.errors[:hat]).to be_present
    end

    it "requires link" do
      req = HatRequest.new(
        user_id: user.id,
        hat: "Developer",
        comment: "Test"
      )

      expect(req.valid?).to eq(false)
      expect(req.errors[:link]).to be_present
    end

    it "requires comment" do
      req = HatRequest.new(
        user_id: user.id,
        hat: "Developer",
        link: "https://example.com"
      )

      expect(req.valid?).to eq(false)
      expect(req.errors[:comment]).to be_present
    end
  end

  describe "associations" do
    it "belongs to user" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://example.com",
        comment: "Test"
      )

      expect(req.user).to be_a(User)
      expect(req.user.id).to eq(user.id)
    end
  end

  describe "#approve_by_user!" do
    it "creates a Hat for the user" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://github.com/username",
        comment: "I contribute to open source"
      )

      expect {
        req.approve_by_user!(moderator)
      }.to change { Hat.count }.by(1)

      hat = Hat.last
      expect(hat.user_id).to eq(user.id)
      expect(hat.granted_by_user_id).to eq(moderator.id)
      expect(hat.hat).to eq("Developer")
      expect(hat.link).to eq("https://github.com/username")
    end

    it "sends approval message to user" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://github.com/username",
        comment: "Test"
      )

      expect {
        req.approve_by_user!(moderator)
      }.to change { Message.count }.by(1)

      msg = Message.last
      expect(msg.recipient_user_id).to eq(user.id)
      expect(msg.author_user_id).to eq(moderator.id)
      expect(msg.subject).to include("Developer")
    end

    it "destroys the hat request" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://github.com/username",
        comment: "Test"
      )

      expect {
        req.approve_by_user!(moderator)
      }.to change { HatRequest.count }.by(-1)
    end

    it "performs all operations in a transaction" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://github.com/username",
        comment: "Test"
      )

      initial_hat_count = Hat.count
      initial_msg_count = Message.count

      req.approve_by_user!(moderator)

      expect(Hat.count).to eq(initial_hat_count + 1)
      expect(Message.count).to eq(initial_msg_count + 1)
      expect(HatRequest.exists?(req.id)).to eq(false)
    end
  end

  describe "#reject_by_user_for_reason!" do
    it "sends rejection message to user" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://github.com/username",
        comment: "Test"
      )

      expect {
        req.reject_by_user_for_reason!(moderator, "Insufficient evidence")
      }.to change { Message.count }.by(1)

      msg = Message.last
      expect(msg.recipient_user_id).to eq(user.id)
      expect(msg.author_user_id).to eq(moderator.id)
      expect(msg.subject).to include("Developer")
      expect(msg.body).to eq("Insufficient evidence")
    end

    it "does not create a Hat" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://github.com/username",
        comment: "Test"
      )

      expect {
        req.reject_by_user_for_reason!(moderator, "Not qualified")
      }.not_to change { Hat.count }
    end

    it "destroys the hat request" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://github.com/username",
        comment: "Test"
      )

      expect {
        req.reject_by_user_for_reason!(moderator, "Rejected")
      }.to change { HatRequest.count }.by(-1)
    end

    it "performs all operations in a transaction" do
      req = HatRequest.create!(
        user_id: user.id,
        hat: "Developer",
        link: "https://github.com/username",
        comment: "Test"
      )

      initial_msg_count = Message.count

      req.reject_by_user_for_reason!(moderator, "Test reason")

      expect(Message.count).to eq(initial_msg_count + 1)
      expect(HatRequest.exists?(req.id)).to eq(false)
    end
  end
end
