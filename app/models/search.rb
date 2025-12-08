class Search
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::AttributeMethods
  extend ActiveModel::Naming

  attr_accessor :q, :what, :order
  attr_accessor :results, :page, :total_results, :per_page

  validates_length_of :q, minimum: 2

  def initialize
    @q = ""
    @what = "all"
    @order = "relevance"

    @page = 1
    @per_page = 20

    @results = []
    @total_results = -1
  end

  def max_matches
    1000
  end

  def persisted?
    false
  end

  def to_url_params
    [:q, :what, :order].map { |p|
      "#{p}=#{CGI.escape(send(p).to_s)}"
    }.join("&amp;")
  end

  def page_count
    total = total_results.to_i

    if total == -1 || total > max_matches
      total = max_matches
    end

    ((total - 1) / per_page.to_i) + 1
  end

  def search_for_user!(user)
    # Extract special search operators
    domain = nil
    submitter = nil
    words = q.to_s.split(" ").reject { |w|
      if (m = w.match(/^domain:(.+)$/))
        domain = m[1]
      elsif (m = w.match(/^submitter:(.+)$/i))
        submitter = m[1]
      end
    }.join(" ")

    # Handle submitter search - find user by username
    submitter_user = nil
    if submitter.present?
      submitter_user = User.find_by("LOWER(username) = ?", submitter.downcase)
      if submitter_user.nil? && words.blank? && domain.blank?
        self.results = []
        self.total_results = 0
        self.page = 0
        return false
      end
    end

    # Handle domain search
    story_ids = []
    if domain.present?
      self.what = "stories"
      begin
        # Escape domain for regex special characters (dots, etc.)
        escaped_domain = Regexp.escape(domain)
        # Pattern: matches //domain or //subdomain.domain followed by / or ? or end of string
        reg = Regexp.new("//([^/]*\\.)?#{escaped_domain}(/|\\?|$)")
      rescue RegexpError
        return false
      end

      story_ids = Story.select(:id)
        .where("`url` REGEXP ?", reg.source)
        .limit(max_matches)
        .pluck(:id)

      if story_ids.empty? && words.blank?
        self.results = []
        self.total_results = 0
        self.page = 0
        return false
      end
    end

    # Sanitize query for FULLTEXT BOOLEAN MODE
    # Escape special characters that have meaning in boolean mode
    sanitized_words = sanitize_fulltext_query(words)
    query = ActiveRecord::Base.connection.quote_string(sanitized_words)

    # Build search based on 'what' parameter
    results_array = []

    if what == "all" || what == "stories"
      results_array.concat(search_stories(query, story_ids, submitter_user))
    end

    if what == "all" || what == "comments"
      results_array.concat(search_comments(query, submitter_user))
    end

    # Sort results
    results_array = sort_results(results_array)

    # Set total before pagination
    self.total_results = results_array.length

    # Paginate
    offset = (page - 1) * per_page
    self.results = results_array[offset, per_page] || []

    if page > page_count && page_count > 0
      self.page = page_count
    end

    # Bind votes for both types
    if (what == "all" || what == "comments") && user
      comment_results = results.select { |r| r.instance_of?(Comment) }
      if comment_results.any?
        votes = Vote.comment_votes_by_user_for_comment_ids_hash(user.id,
          comment_results.map { |c| c.id })

        comment_results.each do |r|
          if votes[r.id]
            r.current_vote = votes[r.id]
          end
        end
      end
    end

    if (what == "all" || what == "stories") && user
      story_results = results.select { |r| r.instance_of?(Story) }
      if story_results.any?
        votes = Vote.story_votes_by_user_for_story_ids_hash(user.id,
          story_results.map { |s| s.id })

        story_results.each do |r|
          if votes[r.id]
            r.vote = votes[r.id]
          end
        end
      end
    end
  rescue => e
    self.results = []
    self.total_results = -1
    Rails.logger.error("Search error: #{e.message}")
    raise e
  end

  private

  def search_stories(query, story_ids = [], submitter_user = nil)
    # Return empty if no query AND no story_ids AND no submitter
    return [] if query.blank? && story_ids.empty? && submitter_user.nil?

    relation = Story.joins(:user).where(is_expired: false)

    # Filter by submitter if specified
    if submitter_user
      relation = relation.where(user_id: submitter_user.id)
    end

    # Filter by story_ids if domain search
    if story_ids.any?
      relation = relation.where(id: story_ids)
    end

    # Add FULLTEXT search only if we have a query
    relation = if query.present?
      relation
        .where("MATCH(stories.title, stories.description, stories.url) AGAINST(? IN BOOLEAN MODE)", query)
        .select("stories.*, MATCH(stories.title, stories.description, stories.url) AGAINST('#{query}' IN BOOLEAN MODE) as relevance")
    else
      # Domain-only or submitter-only search: no relevance score
      relation.select("stories.*, 0 as relevance")
    end

    relation.includes(:user, :tags).to_a
  end

  def search_comments(query, submitter_user = nil)
    # Return empty if no query AND no submitter
    return [] if query.blank? && submitter_user.nil?

    relation = Comment.joins(:user, :story)
      .where(is_deleted: false, is_moderated: false)

    # Filter by submitter if specified
    if submitter_user
      relation = relation.where(user_id: submitter_user.id)
    end

    # Add FULLTEXT search only if we have a query
    relation = if query.present?
      relation
        .where("MATCH(comment) AGAINST(? IN BOOLEAN MODE)", query)
        .select("comments.*, MATCH(comment) AGAINST('#{query}' IN BOOLEAN MODE) as relevance")
    else
      # Submitter-only search: no relevance score
      relation.select("comments.*, 0 as relevance")
    end

    relation.includes(:user, :story).to_a
  end

  def sanitize_fulltext_query(query)
    # In MySQL FULLTEXT BOOLEAN MODE, certain characters have special meaning:
    # + = must include, - = must exclude, * = wildcard, " = phrase, etc.
    # We escape these to treat them as literal characters
    query.to_s.gsub(/[+\-<>()~*"]/, " ")
  end

  def sort_results(results)
    case order
    when "newest"
      results.sort_by { |r| r.created_at }.reverse
    when "points"
      results.sort_by do |r|
        if r.is_a?(Story)
          r.score
        elsif r.is_a?(Comment)
          r.score
        else
          0
        end
      end.reverse
    else # relevance
      results.sort_by { |r| r.respond_to?(:relevance) ? -r.relevance.to_f : 0 }
    end
  end
end
