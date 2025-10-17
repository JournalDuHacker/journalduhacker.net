require "spec_helper"

describe Message do
  let(:sender) { User.make! }
  let(:recipient) { User.make! }

  describe "creation and validation" do
    it "creates a message with required fields" do
      msg = Message.create!(
        author_user_id: sender.id,
        recipient_user_id: recipient.id,
        subject: "Test subject",
        body: "Test body"
      )

      expect(msg).to be_persisted
      expect(msg.author).to eq(sender)
      expect(msg.recipient).to eq(recipient)
    end

    it "requires recipient" do
      msg = Message.new(
        author_user_id: sender.id,
        subject: "Test",
        body: "Test"
      )

      expect(msg.valid?).to eq(false)
      expect(msg.errors[:recipient]).to be_present
    end

    it "validates subject length" do
      msg = Message.new(
        author_user_id: sender.id,
        recipient_user_id: recipient.id,
        subject: "",
        body: "Test"
      )
      expect(msg.valid?).to eq(false)

      msg.subject = "a" * 151
      expect(msg.valid?).to eq(false)

      msg.subject = "Valid subject"
      expect(msg.valid?).to eq(true)
    end

    it "validates body maximum length" do
      msg = Message.new(
        author_user_id: sender.id,
        recipient_user_id: recipient.id,
        subject: "Test",
        body: "a" * (64 * 1024 + 1)
      )

      expect(msg.valid?).to eq(false)
    end
  end

  describe "short_id generation" do
    it "generates a short_id on creation" do
      msg = Message.make!
      expect(msg.short_id).to match(/^\A[a-zA-Z0-9]{1,10}\z/)
    end

    it "generates unique short_ids" do
      m1 = Message.make!
      m2 = Message.make!

      expect(m1.short_id).not_to eq(m2.short_id)
    end
  end

  describe "associations" do
    it "belongs to author user" do
      msg = Message.make!(author_user_id: sender.id)
      expect(msg.author).to be_a(User)
      expect(msg.author.id).to eq(sender.id)
    end

    it "belongs to recipient user" do
      msg = Message.make!(recipient_user_id: recipient.id)
      expect(msg.recipient).to be_a(User)
      expect(msg.recipient.id).to eq(recipient.id)
    end
  end

  describe "#author_username" do
    it "returns author's username" do
      msg = Message.make!(author_user_id: sender.id)
      expect(msg.author_username).to eq(sender.username)
    end
  end

  describe "#recipient_username=" do
    it "sets recipient by username" do
      msg = Message.new(
        author_user_id: sender.id,
        subject: "Test",
        body: "Test"
      )

      msg.recipient_username = recipient.username
      expect(msg.recipient_user_id).to eq(recipient.id)
    end

    it "adds error for invalid username" do
      msg = Message.new(
        author_user_id: sender.id,
        subject: "Test",
        body: "Test"
      )

      msg.recipient_username = "nonexistent_user_123"
      expect(msg.errors[:recipient_username]).to be_present
    end
  end

  describe "read status" do
    it "defaults to unread" do
      msg = Message.make!
      expect(msg.has_been_read).to eq(false)
    end

    it "can be marked as read" do
      msg = Message.make!
      msg.update!(has_been_read: true)
      expect(msg.has_been_read).to eq(true)
    end

    it "unread scope filters unread messages" do
      read = Message.make!(has_been_read: true)
      unread = Message.make!(has_been_read: false)

      messages = Message.unread
      expect(messages).to include(unread)
      expect(messages).not_to include(read)
    end

    it "unread scope excludes deleted by recipient" do
      msg = Message.make!(
        has_been_read: false,
        deleted_by_recipient: true
      )

      expect(Message.unread).not_to include(msg)
    end
  end

  describe "deletion" do
    it "tracks deletion by author" do
      msg = Message.make!
      msg.update!(deleted_by_author: true)
      expect(msg.deleted_by_author).to eq(true)
    end

    it "tracks deletion by recipient" do
      msg = Message.make!
      msg.update!(deleted_by_recipient: true)
      expect(msg.deleted_by_recipient).to eq(true)
    end

    it "destroys message when deleted by both" do
      msg = Message.make!
      msg.update!(deleted_by_author: true)

      expect {
        msg.update!(deleted_by_recipient: true)
      }.to change { Message.count }.by(-1)
    end

    it "does not destroy when only deleted by one party" do
      msg = Message.make!

      expect {
        msg.update!(deleted_by_author: true)
      }.not_to change { Message.count }
    end
  end

  describe "markdown rendering" do
    it "converts body to HTML" do
      msg = Message.create!(
        author_user_id: sender.id,
        recipient_user_id: recipient.id,
        subject: "Test",
        body: "**Bold text**"
      )

      html = msg.linkified_body
      expect(html).to include("<strong>")
    end

    it "returns plain text body" do
      msg = Message.create!(
        author_user_id: sender.id,
        recipient_user_id: recipient.id,
        subject: "Test",
        body: "Plain text"
      )

      expect(msg.plaintext_body).to eq("Plain text")
    end
  end

  describe "#url" do
    it "generates correct URL" do
      msg = Message.make!
      expect(msg.url).to include("/messages/#{msg.short_id}")
    end
  end

  describe "callbacks" do
    it "updates recipient unread message count after save" do
      initial_count = recipient.unread_message_count

      Message.create!(
        author_user_id: sender.id,
        recipient_user_id: recipient.id,
        subject: "Test",
        body: "Test",
        has_been_read: false
      )

      recipient.reload
      expect(recipient.unread_message_count).to be > initial_count
    end
  end
end
