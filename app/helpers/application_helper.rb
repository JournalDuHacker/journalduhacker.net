module ApplicationHelper
  MAX_PAGES = 15

  def avatar_img(user, size)
    image_tag(user.avatar_url(size), {
      :srcset => "#{user.avatar_url(size)} 1x, " <<
        "#{user.avatar_url(size * 2)} 2x",
      :class => "avatar",
      :size => "#{size}x#{size}",
      :alt => "#{user.username} avatar" })
  end

  def break_long_words(str, len = 30)
    safe_join(str.split(" ").map{|w|
      if w.length > len
        safe_join(w.split(/(.{#{len}})/), "<wbr>".html_safe)
      else
        w
      end
    }, " ")
  end

  def errors_for(object, message=nil)
    html = ""
    unless object.errors.blank?
      html << "<div class=\"flash-error\">\n"
      object.errors.full_messages.each do |error|
        html << error << "<br>"
      end
      html << "</div>\n"
    end

    raw(html)
  end

  # Replacement for dynamic_form's error_messages_for
  # Displays validation errors in a formatted div with the errorExplanation class
  def error_messages_for(object, options = {})
    return "" if object.errors.empty?

    object_name = options[:object_name] || object.class.model_name.human.downcase
    count = object.errors.count
    header_message = options[:header_message] || I18n.t(
      "activerecord.errors.template.header",
      count: count,
      model: object_name,
      default: "#{count} #{count == 1 ? 'error' : 'errors'} prohibited this #{object_name} from being saved"
    )
    message = options[:message] || I18n.t(
      "activerecord.errors.template.body",
      default: "There were problems with the following fields:"
    )

    html = <<-HTML
      <div class="errorExplanation" id="errorExplanation">
        <h2>#{header_message}</h2>
        <p>#{message}</p>
        <ul>
    HTML

    object.errors.full_messages.each do |msg|
      html << "<li>#{ERB::Util.html_escape(msg)}</li>\n"
    end

    html << "</ul></div>"

    raw(html)
  end

  def page_numbers_for_pagination(max, cur)
    if max <= MAX_PAGES
      return (1 .. max).to_a
    end

    pages = (cur - (MAX_PAGES / 2) + 1 .. cur + (MAX_PAGES / 2) - 1).to_a

    while pages[0] < 1
      pages.push (pages.last + 1)
      pages.shift
    end

    while pages.last > max
      if pages[0] > 1
        pages.unshift (pages[0] - 1)
      end
      pages.pop
    end

    if pages[0] != 1
      if pages[0] != 2
        pages.unshift "..."
      end
      pages.unshift 1
    end

    if pages.last != max
      if pages.last != max - 1
        pages.push "..."
      end
      pages.push max
    end

    pages
  end

  def time_ago_in_words_label(time, options = {})
    ago = ""
    secs = (Time.now - time).to_i
    if secs <= 5
      ago = "just now"
    elsif secs < 60
      ago = "less than a minute ago"
    elsif secs < (60 * 60)
      mins = (secs / 60.0).floor
      ago = "#{mins} minute#{mins == 1 ? "" : "s"} ago"
    elsif secs < (60 * 60 * 48)
      hours = (secs / 60.0 / 60.0).floor
      ago = "#{hours} hour#{hours == 1 ? "" : "s"} ago"
    elsif secs < (60 * 60 * 24 * 30)
      days = (secs / 60.0 / 60.0 / 24.0).floor
      ago = "#{days} day#{days == 1 ? "" : "s"} ago"
    elsif secs < (60 * 60 * 24 * 365)
      months = (secs / 60.0 / 60.0 / 24.0 / 30.0).floor
      ago = "#{months} month#{months == 1 ? "" : "s"} ago"
    else
      years = (secs / 60.0 / 60.0 / 24.0 / 365.0).floor
      ago = "#{years} year#{years == 1 ? "" : "s"} ago"
    end

    raw(content_tag(:span, ago, :title => time.strftime("%F %T %z")))
  end
end
