class HatRequest < ApplicationRecord
  belongs_to :user

  validates :user, presence: true
  validates :hat, presence: true
  validates :link, presence: true
  validates :comment, presence: true

  attr_accessor :rejection_comment

  def approve_by_user!(user)
    transaction do
      h = Hat.new
      h.user_id = user_id
      h.granted_by_user_id = user.id
      h.hat = hat
      h.link = link
      h.save!

      m = Message.new
      m.author_user_id = user.id
      m.recipient_user_id = user_id
      m.subject = I18n.t "models.hat.grantsubject", hat: hat.to_s
      m.body = I18n.t "models.hat.grantbody"
      m.save!

      destroy
    end
  end

  def reject_by_user_for_reason!(user, reason)
    transaction do
      m = Message.new
      m.author_user_id = user.id
      m.recipient_user_id = user_id
      m.subject = I18n.t "models.hat.rejectsubject", hat: hat.to_s
      m.body = reason
      m.save!

      destroy
    end
  end
end
