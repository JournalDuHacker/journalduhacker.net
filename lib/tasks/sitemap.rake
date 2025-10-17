namespace :sitemap do
  desc "Generate sitemap.xml file"
  task generate: :environment do
    require "sitemap_generator"
    SitemapGenerator::Sitemap.default_host = "https://journalduhacker.net"
    SitemapGenerator::Sitemap.create do
      # Static pages
      add "/", priority: 1.0, changefreq: "hourly"
      add "/newest", priority: 0.9, changefreq: "hourly"
      add "/recent", priority: 0.9, changefreq: "hourly"
      add "/about", priority: 0.5, changefreq: "monthly"
      add "/privacy", priority: 0.3, changefreq: "monthly"

      # Stories
      Story.where(is_expired: false).find_each do |story|
        add story.comments_path, lastmod: story.created_at, priority: 0.8
      end

      # Tags
      Tag.active.find_each do |tag|
        add "/t/#{tag.tag}", priority: 0.7
      end
    end
  end

  desc "Refresh sitemap (generate and ping search engines)"
  task refresh: :generate do
    SitemapGenerator::Sitemap.ping_search_engines
  end
end
