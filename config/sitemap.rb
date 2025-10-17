# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://journalduhacker.net"
SitemapGenerator::Sitemap.compress = true
SitemapGenerator::Sitemap.create_index = true

SitemapGenerator::Sitemap.create do
  # Static pages
  add "/", priority: 1.0, changefreq: "hourly"
  add "/newest", priority: 0.9, changefreq: "hourly"
  add "/recent", priority: 0.9, changefreq: "hourly"
  add "/about", priority: 0.5, changefreq: "monthly"
  add "/privacy", priority: 0.3, changefreq: "monthly"
  add "/search", priority: 0.6, changefreq: "daily"

  # Top pages with different time periods
  ["d", "w", "m", "y"].each do |period|
    add "/top/#{period}", priority: 0.7, changefreq: "daily"
  end

  # Stories - published and visible
  Story.where(is_expired: false, is_moderated: false)
    .where("created_at > ?", 2.years.ago)
    .find_each do |story|
    add story.comments_path,
      lastmod: story.created_at,
      priority: 0.8,
      changefreq: "daily"
  end

  # Tags - active tags only
  Tag.active.find_each do |tag|
    add "/t/#{tag.tag}",
      priority: 0.7,
      changefreq: "daily"
  end

  # User profiles - active users with karma > 0
  User.where("karma > ?", 0)
    .where(banned_at: nil)
    .find_each do |user|
    add "/u/#{user.username}",
      priority: 0.5,
      changefreq: "weekly"
  end
end
