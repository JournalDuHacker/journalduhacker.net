class InvitationMailer < ActionMailer::Base
  def invitation(invitation)
    @invitation = invitation

    mail(
      to: invitation.email,
      subject: I18n.t("mailers.invitation_mailer.subject", appname: Rails.application.name.to_s)
    )
  end
end
