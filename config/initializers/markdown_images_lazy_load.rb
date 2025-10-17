# Add lazy loading to images in markdown content
# This processes HTML after markdown rendering to add loading="lazy" attribute

module MarkdownLazyLoadImages
  def self.process(html)
    return html if html.blank?

    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    doc.css("img").each do |img|
      # Add lazy loading
      img["loading"] = "lazy" unless img["loading"]

      # Add explicit width/height if not present (helps with CLS - Cumulative Layout Shift)
      # These are placeholder values, ideally you'd extract actual dimensions
      unless img["width"] || img["height"]
        img["decoding"] = "async"
      end
    end

    doc.to_html.html_safe
  end
end

Rails.application.config.after_initialize do
  # Monkey patch Markdowner to add lazy loading
  Markdowner.singleton_class.class_eval do
    alias_method :original_to_html, :to_html

    def to_html(text, options = {})
      html = original_to_html(text, options)
      MarkdownLazyLoadImages.process(html)
    end
  end
end
