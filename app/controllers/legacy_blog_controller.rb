require "cgi"

class LegacyBlogController < ApplicationController
  skip_before_action :authenticate_user
  skip_before_action :increase_traffic_counter

  def feed
    redirect_to blog_posts_url(canonical_url_options.merge(format: :rss)), status: :moved_permanently, allow_other_host: true
  end

  def article
    legacy_id, slug = extract_legacy_reference

    if legacy_id
      if (post = BlogPost.find_by(legacy_identifier: legacy_id))
        return redirect_to blog_post_url(post, canonical_url_options), status: :moved_permanently, allow_other_host: true
      end
    end

    if slug.present?
      normalized_slug = slug.parameterize
      if (post_by_slug = BlogPost.find_by(slug: normalized_slug))
        return redirect_to blog_post_url(post_by_slug, canonical_url_options), status: :moved_permanently, allow_other_host: true
      end
    end

    redirect_to blog_posts_url(canonical_url_options), status: :moved_permanently, allow_other_host: true
  end

  private

  def canonical_url_options
    {
      host: Rails.application.domain,
      protocol: Rails.application.ssl? ? "https" : "http"
    }
  end

  def extract_legacy_reference
    query = request.query_string.to_s
    return [nil, nil] if query.blank?

    if (matches = query.match(/\Aarticle(?<id>\d+)(?:\/(?<slug>[^&]+))?/))
      legacy_id = matches[:id].to_i
      slug = matches[:slug] ? CGI.unescape(matches[:slug]) : nil
      return [legacy_id, slug]
    end

    [nil, nil]
  end
end
