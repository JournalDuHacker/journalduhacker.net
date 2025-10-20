class EmailReply < ActionMailer::Base
  def reply(comment, user)
    @comment = comment
    @user = user

    mail(
      to: user.email,
      subject: I18n.t("mailers.email_reply.replysubject", appname: Rails.application.name.to_s, author: comment.user.username.to_s, story: comment.story.title.to_s)
    )
  end

  def mention(comment, user)
    @comment = comment
    @user = user

    mail(
      to: user.email,
      subject: I18n.t("mailers.email_reply.mentionsubject", appname: Rails.application.name.to_s, author: comment.user.username.to_s, story: comment.story.title.to_s)
    )
  end
end
