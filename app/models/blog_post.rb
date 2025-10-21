require "securerandom"

class BlogPost < ApplicationRecord
  belongs_to :user

  before_validation :generate_slug
  before_validation :set_default_published_at
  before_save :cache_markdown

  validates :title, presence: true
  validates :body, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :user, presence: true
  validates :legacy_identifier, uniqueness: true, allow_nil: true

  scope :published, -> {
    where(draft: false)
      .where("published_at <= ?", Time.current)
      .order(published_at: :desc)
  }

  def to_param
    slug
  end

  def published?
    !draft? && published_at.present? && published_at <= Time.current
  end

  def summary(length = 280)
    text = ActionView::Base.full_sanitizer.sanitize(markeddown_body.to_s)
    text = text.squish
    return text if text.length <= length

    truncated = text[0, length].gsub(/\s\w+\z/, "")
    "#{truncated}…"
  end

  private

  def generate_slug
    base = slug.presence || title.to_s.parameterize
    base = SecureRandom.hex(4) if base.blank?

    candidate = base
    suffix = 2

    while BlogPost.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end

  def set_default_published_at
    self.published_at ||= Time.current
  end

  def cache_markdown
    self.markeddown_body = if body.to_s.strip.start_with?("<")
      body.to_s
    else
      Markdowner.to_html(body, allow_images: true)
    end
  rescue
    self.markeddown_body = body.to_s
  end
end
