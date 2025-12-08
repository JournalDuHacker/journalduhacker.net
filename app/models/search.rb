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
    # Extract domain query since it must be done separately
    domain = nil
    words = q.to_s.split(" ").reject { |w|
      if (m = w.match(/^domain:(.+)$/))
        domain = m[1]
      end
    }.join(" ")

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

    # Escape query for FULLTEXT search
    query = ActiveRecord::Base.connection.quote_string(words)

    # Build search based on 'what' parameter
    results_array = []

    if what == "all" || what == "stories"
      results_array.concat(search_stories(query, story_ids))
    end

    if what == "all" || what == "comments"
      results_array.concat(search_comments(query))
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

  def search_stories(query, story_ids = [])
    # Return empty if no query AND no story_ids (domain search)
    return [] if query.blank? && story_ids.empty?

    relation = Story.joins(:user).where(is_expired: false)

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
      # Domain-only search: no relevance score
      relation.select("stories.*, 0 as relevance")
    end

    relation.includes(:user, :tags).to_a
  end

  def search_comments(query)
    return [] if query.blank?

    Comment.joins(:user, :story)
      .where(is_deleted: false, is_moderated: false)
      .where("MATCH(comment) AGAINST(? IN BOOLEAN MODE)", query)
      .select("comments.*,
        MATCH(comment) AGAINST('#{query}' IN BOOLEAN MODE) as relevance")
      .includes(:user, :story)
      .to_a
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
