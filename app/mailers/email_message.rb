class EmailMessage < ActionMailer::Base
  def notify(message, user)
    @message = message
    @user = user

    mail(
      to: user.email,
      subject: I18n.t("mailers.email_message.subject", appname: Rails.application.name.to_s, author: message.author_username.to_s, subject: message.subject.to_s)
    )
  end
end
