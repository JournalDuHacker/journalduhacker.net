class InvitationRequestMailer < ActionMailer::Base
  def invitation_request(invitation_request)
    @invitation_request = invitation_request

    mail(
      to: invitation_request.email,
      subject: I18n.t("mailers.invitation_request_mailer.subject", appname: Rails.application.name.to_s)
    )
  end
end
