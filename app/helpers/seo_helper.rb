module SeoHelper
  # Set SEO meta tags for a page
  # Usage in controller:
  #   set_seo_meta(
  #     title: "My Page Title",
  #     description: "My page description",
  #     image: "https://example.com/image.jpg",
  #     type: "article"
  #   )
  def set_seo_meta(title: nil, description: nil, keywords: nil, image: nil, type: "website", url: nil)
    @title = title if title.present?
    @meta_description = description if description.present?
    @meta_keywords = keywords if keywords.present?
    @canonical_url = url if url.present?

    # Build meta tags hash
    @meta_tags ||= {}

    # OpenGraph tags
    @meta_tags["og:title"] = @title || Rails.application.name
    @meta_tags["og:description"] = @meta_description if @meta_description.present?
    @meta_tags["og:type"] = type
    @meta_tags["og:url"] = @canonical_url || request.original_url
    @meta_tags["og:site_name"] = Rails.application.name
    @meta_tags["og:image"] = image || default_og_image

    # Twitter Card tags
    @meta_tags["twitter:card"] = image.present? ? "summary_large_image" : "summary"
    @meta_tags["twitter:site"] = "@journalduhacker"
    @meta_tags["twitter:title"] = @title || Rails.application.name
    @meta_tags["twitter:description"] = @meta_description if @meta_description.present?
    @meta_tags["twitter:image"] = @meta_tags["og:image"]

    @meta_tags
  end

  # Extract first image URL from HTML content
  def extract_first_image(html_content)
    return nil if html_content.blank?

    doc = Nokogiri::HTML(html_content)
    img = doc.at_css("img")
    return nil unless img

    src = img["src"]
    return nil if src.blank?

    # Make absolute URL if relative
    if src.start_with?("//")
      "https:#{src}"
    elsif src.start_with?("/")
      "#{Rails.application.root_url.chomp("/")}#{src}"
    elsif !src.start_with?("http")
      "#{Rails.application.root_url.chomp("/")}/#{src}"
    else
      src
    end
  rescue => e
    Rails.logger.error "Error extracting image: #{e.message}"
    nil
  end

  # Default OpenGraph image
  def default_og_image
    "#{Rails.application.root_url}apple-touch-icon-144.png"
  end

  # Truncate text smartly for meta descriptions
  def truncate_for_meta(text, length: 160)
    return "" if text.blank?

    # Strip HTML tags
    clean_text = ActionView::Base.full_sanitizer.sanitize(text)
    # Decode HTML entities
    clean_text = HTMLEntities.new.decode(clean_text)
    # Remove extra whitespace
    clean_text = clean_text.gsub(/\s+/, " ").strip

    if clean_text.length <= length
      clean_text
    else
      # Truncate at word boundary
      truncated = clean_text[0...length].gsub(/\s\w+\s*$/, "")
      "#{truncated}..."
    end
  end

  # Generate structured data JSON-LD
  def structured_data_article(story)
    data = {
      "@context": "https://schema.org",
      "@type": "DiscussionForumPosting",
      headline: story.title,
      url: story.comments_url,
      datePublished: story.created_at.iso8601,
      author: {
        "@type": "Person",
        name: story.user.username
      },
      interactionStatistic: {
        "@type": "InteractionCounter",
        interactionType: "https://schema.org/CommentAction",
        userInteractionCount: story.comments_count
      },
      discussionUrl: story.comments_url,
      commentCount: story.comments_count,
      publisher: {
        "@type": "Organization",
        name: Rails.application.name,
        url: Rails.application.root_url
      }
    }

    # Add article body if description exists
    if story.description.present?
      data["articleBody"] = truncate_for_meta(story.markeddown_description, length: 300)
    end

    # Add shared content URL if external link
    if story.url.present?
      data["sharedContent"] = {
        "@type": "WebPage",
        url: story.url
      }
    end

    # Add image if available
    if story.markeddown_description.present?
      image_url = extract_first_image(story.markeddown_description)
      if image_url.present?
        data["image"] = image_url
      end
    end

    data
  end

  # Generate breadcrumb structured data
  def structured_data_breadcrumb(items)
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: items.each_with_index.map do |item, index|
        {
          "@type": "ListItem",
          position: index + 1,
          name: item[:name],
          item: item[:url]
        }
      end
    }
  end

  # Render JSON-LD structured data
  def render_structured_data(data)
    content_tag(:script, data.to_json.html_safe, type: "application/ld+json")
  end
end
