class Hat < ApplicationRecord
  belongs_to :user
  belongs_to :granted_by_user,
    class_name: "User"

  validates :user, presence: true
  validates :granted_by_user, presence: true

  after_create :log_moderation

  def destroy_by_user_with_reason(user, reason)
    m = Moderation.new
    m.user_id = user_id
    m.moderator_user_id = user.id
    m.action = "Revoked hat \"#{hat}\": #{reason}"
    m.save!

    destroy
  end

  def to_html_label
    hl = link.present? && link.match(/^https?:\/\//)

    h = I18n.t "models.hat.grantedby", hat: hat.gsub(/[^A-Za-z0-9]/, "_").downcase.to_s, inviteuser: granted_by_user.username.to_s, invitedate: created_at.strftime("%Y-%m-%d").to_s

    if !hl && link.present?
      h << " - #{ERB::Util.html_escape(link)}"
    end

    h << "\">" \
      "<span class=\"crown\">"

    if hl
      h << "<a href=\"#{ERB::Util.html_escape(link)}\" target=\"_blank\">"
    end

    h << ERB::Util.html_escape(hat)

    if hl
      h << "</a>"
    end

    h << "</span></span>"

    h.html_safe
  end

  def log_moderation
    m = Moderation.new
    m.created_at = created_at
    m.user_id = user_id
    m.moderator_user_id = granted_by_user_id
    m.action = "Granted hat \"#{hat}\"" + (link.present? ?
      " (#{link})" : "")
    m.save
  end
end
