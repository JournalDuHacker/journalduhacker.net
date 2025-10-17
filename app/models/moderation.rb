class Moderation < ApplicationRecord
  belongs_to :moderator,
    class_name: "User",
    foreign_key: "moderator_user_id",
    optional: true
  belongs_to :story, optional: true
  belongs_to :comment, optional: true
  belongs_to :user, optional: true

  after_create :send_message_to_moderated

  def send_message_to_moderated
    m = Message.new
    m.author_user_id = moderator_user_id

    # mark as deleted by author so they don't fill up moderator message boxes
    m.deleted_by_author = true

    if story
      m.recipient_user_id = story.user_id
      m.subject = I18n.t("models.moderation.storyeditedby") <<
        (is_from_suggestions? ? I18n.t("models.moderation.usersuggestions") : I18n.t("models.moderation.amoderator"))
      m.body = I18n.t("models.moderation.storyeditedfor", title: story.title.to_s, url: story.comments_url.to_s) <<
        "\n" \
        "> *#{action}*\n"

      if reason.present?
        m.body << "\n" <<
          I18n.t("models.moderation.reasongiven") <<
          "\n" \
          "> *#{reason}*\n"
      end

    elsif comment
      m.recipient_user_id = comment.user_id
      m.subject = I18n.t("models.moderation.commentmoderated")
      m.body = I18n.t("models.moderation.commentmoderatedwhy", title: comment.story.title.to_s, url: comment.story.comments_url.to_s) <<
        "\n" \
        "> *#{comment.comment}*\n"

      if reason.present?
        m.body << "\n" <<
          I18n.t("models.moderation.reasongiven") <<
          "\n" \
          "> *#{reason}*\n"
      end

    else
      # no point in alerting deleted users, they can't login to read it
      return
    end

    m.body << "\n" <<
      I18n.t("models.moderation.automatedmessage")

    m.save
  end
end
