class Search
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::AttributeMethods
  extend ActiveModel::Naming

  attr_accessor :q, :what, :order
  attr_accessor :results, :page, :total_results, :per_page

  validates_length_of :q, :minimum => 2

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
    [ :q, :what, :order ].map{|p| "#{p}=#{CGI.escape(self.send(p).to_s)}"
      }.join("&amp;")
  end

  def page_count
    total = self.total_results.to_i

    if total == -1 || total > self.max_matches
      total = self.max_matches
    end

    ((total - 1) / self.per_page.to_i) + 1
  end

  def search_for_user!(user)
    # Extract domain query since it must be done separately
    domain = nil
    words = self.q.to_s.split(" ").reject{|w|
      if m = w.match(/^domain:(.+)$/)
        domain = m[1]
      end
    }.join(" ")

    # Handle domain search
    story_ids = []
    if domain.present?
      self.what = "stories"
      begin
        reg = Regexp.new("//([^/]*\.)?#{domain}/")
      rescue RegexpError
        return false
      end

      story_ids = Story.select(:id).where("`url` REGEXP '" +
        ActiveRecord::Base.connection.quote_string(reg.source) + "'").
        collect(&:id)

      if story_ids.empty?
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

    if self.what == "all" || self.what == "stories"
      results_array.concat(search_stories(query, story_ids))
    end

    if self.what == "all" || self.what == "comments"
      results_array.concat(search_comments(query))
    end

    # Sort results
    results_array = sort_results(results_array)

    # Set total before pagination
    self.total_results = results_array.length

    # Paginate
    offset = (self.page - 1) * self.per_page
    self.results = results_array[offset, self.per_page] || []

    if self.page > self.page_count && self.page_count > 0
      self.page = self.page_count
    end

    # Bind votes for both types
    if (self.what == "all" || self.what == "comments") && user
      comment_results = self.results.select{|r| r.class == Comment }
      if comment_results.any?
        votes = Vote.comment_votes_by_user_for_comment_ids_hash(user.id,
          comment_results.map{|c| c.id })

        comment_results.each do |r|
          if votes[r.id]
            r.current_vote = votes[r.id]
          end
        end
      end
    end

    if (self.what == "all" || self.what == "stories") && user
      story_results = self.results.select{|r| r.class == Story }
      if story_results.any?
        votes = Vote.story_votes_by_user_for_story_ids_hash(user.id,
          story_results.map{|s| s.id })

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
    return [] if query.blank?

    relation = Story.joins(:user)
      .where(is_expired: false)
      .where("MATCH(stories.title, stories.description, stories.url) AGAINST(? IN BOOLEAN MODE)", query)

    # Filter by story_ids if domain search
    if story_ids.any?
      relation = relation.where(id: story_ids)
    end

    relation.select("stories.*,
      MATCH(stories.title, stories.description, stories.url) AGAINST('#{query}' IN BOOLEAN MODE) as relevance")
      .includes(:user, :tags)
      .to_a
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
      results.sort_by{|r| r.created_at }.reverse
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
      results.sort_by{|r| r.respond_to?(:relevance) ? -r.relevance.to_f : 0 }
    end
  end
end
