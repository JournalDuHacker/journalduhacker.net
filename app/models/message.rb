class Message < ApplicationRecord
  belongs_to :recipient,
    class_name: "User",
    foreign_key: "recipient_user_id"
  belongs_to :author,
    class_name: "User",
    foreign_key: "author_user_id"

  validates_presence_of :recipient

  attr_reader :recipient_username

  validates_length_of :subject, in: 1..150
  validates_length_of :body, maximum: (64 * 1024)

  scope :unread, -> {
    where(has_been_read: false,
      deleted_by_recipient: false)
  }

  before_validation :assign_short_id,
    on: :create
  after_create :deliver_email_notifications
  after_save :update_unread_counts
  after_save :check_for_both_deleted

  def assign_short_id
    self.short_id = ShortId.new(self.class).generate
  end

  def author_username
    if author
      author.username
    else
      "System"
    end
  end

  def check_for_both_deleted
    if deleted_by_author? && deleted_by_recipient?
      destroy
    end
  end

  def update_unread_counts
    recipient.update_unread_message_count!
  end

  def deliver_email_notifications
    return if Rails.env.development?

    if recipient.email_messages?
      begin
        EmailMessage.notify(self, recipient).deliver_now
      rescue => e
        Rails.logger.error "error e-mailing #{recipient.email}: #{e}"
      end
    end

    if recipient.pushover_messages?
      recipient.pushover!({
        title: "#{Rails.application.name} message from " \
          "#{author_username}: #{subject}",
        message: plaintext_body,
        url: url,
        url_title: (author ? "Reply to #{author_username}" :
          "View message")
      })
    end
  end

  def recipient_username=(username)
    self.recipient_user_id = nil

    if (u = User.where(username: username).first)
      self.recipient_user_id = u.id
      @recipient_username = username
    else
      errors.add(:recipient_username, "is not a valid user")
    end
  end

  def linkified_body
    Markdowner.to_html(body)
  end

  def plaintext_body
    body.to_s
  end

  def url
    Rails.application.root_url + "messages/#{short_id}"
  end
end
