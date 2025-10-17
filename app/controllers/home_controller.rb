class HomeController < ApplicationController
  # for rss feeds, load the user's tag filters if a token is passed
  before_action :find_user_from_rss_token, only: [:index, :newest]
  before_action { @page = page }
  before_action :require_logged_in_user, only: [:upvoted]

  def four_oh_four
    @title = "Resource Not Found"
    render action: "404", status: 404
  rescue ActionView::MissingTemplate
    render text: "<div class=\"box wide\">" \
      "<div class=\"legend\">404</div>" \
      "Resource not found" \
      "</div>", layout: "application"
  end

  def about
    @title = I18n.t "controllers.home_controller.abouttitle"
    @meta_description = "À propos de Journal du hacker, la communauté francophone de partage d'actualités tech, programmation et hacking. Découvrez notre histoire et nos valeurs."
  end

  def chat
    @title = I18n.t "controllers.home_controller.chattitle"
    @meta_description = "Rejoignez le chat de la communauté Journal du hacker pour discuter en temps réel de technologie, programmation et sécurité informatique."
  end

  def privacy
    @title = I18n.t "controllers.home_controller.privacytitle"
    @meta_description = "Politique de confidentialité de Journal du hacker. Découvrez comment nous collectons et utilisons vos données personnelles sur notre plateforme."
  end

  def hidden
    @stories, @show_more = get_from_cache(hidden: true) {
      paginate stories.hidden
    }

    @heading = @title = I18n.t "controllers.home_controller.hiddenstoriestitle"
    @cur_url = "/hidden"

    render action: "index"
  end

  def index
    @stories, @show_more = get_from_cache(hottest: true) {
      paginate stories.hottest
    }

    @rss_link ||= {title: "RSS 2.0",
                   href: "/rss#{"?token=#{@user.rss_token}" if @user}"}
    @comments_rss_link ||= {title: "Comments - RSS 2.0",
                            href: "/comments.rss#{"?token=#{@user.rss_token}" if @user}"}

    @heading = ""
    @title = "Actualités Tech, Hacking et Programmation"
    @meta_description = "Journal du hacker - Communauté francophone de partage et discussion d'actualités sur la technologie, la programmation, la sécurité et le hacking. Découvrez les meilleurs liens tech du moment."
    @cur_url = "/"
    @canonical_url = Rails.application.root_url.chomp("/")

    respond_to do |format|
      format.html { render action: "index" }
      format.rss {
        if @user && params[:token].present?
          @title = "Private feed for #{@user.username}"
        end

        render action: "rss", layout: false
      }
      format.json { render json: @stories }
    end
  end

  def newest
    @stories, @show_more = get_from_cache(newest: true) {
      paginate stories.newest
    }

    @heading = @title = I18n.t "controllers.home_controller.neweststoriestitle"
    @meta_description = "Les dernières actualités tech et liens partagés sur Journal du hacker, par ordre chronologique."
    @cur_url = "/newest"

    @rss_link = {title: "RSS 2.0 - Newest Items",
                 href: "/newest.rss#{"?token=#{@user.rss_token}" if @user}"}

    respond_to do |format|
      format.html { render action: "index" }
      format.rss {
        if @user && params[:token].present?
          @title += " - Private feed for #{@user.username}"
        end

        render action: "rss", layout: false
      }
      format.json { render json: @stories }
    end
  end

  def newest_by_user
    by_user = User.where(username: params[:user]).first!

    @stories, @show_more = get_from_cache(by_user: by_user) {
      paginate stories.newest_by_user(by_user)
    }

    @heading = @title = "Newest Stories by #{by_user.username}"
    @cur_url = "/newest/#{by_user.username}"

    @newest = true
    @for_user = by_user.username

    respond_to do |format|
      format.html { render action: "index" }
      format.rss {
        render action: "rss", layout: false
      }
      format.json { render json: @stories }
    end
  end

  def recent
    @stories, @show_more = get_from_cache(recent: true) {
      scope = if page == 1
        stories.recent
      else
        stories.newest
      end
      paginate scope
    }

    @heading = @title = I18n.t "controllers.home_controller.recenttitle"
    @cur_url = "/recent"

    # our content changes every page load, so point at /newest.rss to be stable
    @rss_link = {title: "RSS 2.0 - Newest Items",
                 href: "/newest.rss#{"?token=#{@user.rss_token}" if @user}"}

    render action: "index"
  end

  def tagged
    @tag = Tag.where(tag: params[:tag]).first!

    @stories, @show_more = get_from_cache(tag: @tag) {
      paginate stories.tagged(@tag)
    }

    @heading = @title = @tag.description.blank? ? @tag.tag : @tag.description
    @meta_description = "Actualités et discussions tagguées '#{@tag.tag}' sur Journal du hacker. #{@tag.description}"
    @cur_url = tag_url(@tag.tag)

    @rss_link = {title: "RSS 2.0 - Tagged #{@tag.tag} (#{@tag.description})",
                 href: "/t/#{@tag.tag}.rss"}

    respond_to do |format|
      format.html { render action: "index" }
      format.rss { render action: "rss", layout: false }
      format.json { render json: @stories }
    end
  end

  TOP_INTVS = {"d" => "Day", "w" => "Week", "m" => "Month", "y" => "Year"}
  def top
    @cur_url = "/top"
    length = {dur: 1, intv: "Week"}

    if (m = params[:length].to_s.match(/\A(\d+)([#{TOP_INTVS.keys.join}])\z/))
      length[:dur] = m[1].to_i
      length[:intv] = TOP_INTVS[m[2]]

      @cur_url << "/#{params[:length]}"
    end

    @stories, @show_more = get_from_cache(top: true, length: length) {
      paginate stories.top(length)
    }

    @heading = @title = if length[:dur] > 1
                 "Top Stories of the Past #{length[:dur]} " <<
                   length[:intv] << "s"
               else
                 "Top Stories of the Past " << length[:intv]
               end

    render action: "index"
  end

  def upvoted
    @stories, @show_more = get_from_cache(upvoted: true, user: @user) {
      paginate @user.upvoted_stories.order("votes.id DESC")
    }

    @heading = @title = "Your Upvoted Stories"
    @cur_url = "/upvoted"

    @rss_link = {title: "RSS 2.0 - Your Upvoted Stories",
                 href: "/upvoted.rss#{"?token=#{@user.rss_token}" if @user}"}

    respond_to do |format|
      format.html { render action: "index" }
      format.rss {
        if @user && params[:token].present?
          @title += " - Private feed for #{@user.username}"
        end

        render action: "rss", layout: false
      }
      format.json { render json: @stories }
    end
  end

  private

  def filtered_tag_ids
    if @user
      @user.tag_filters.map { |tf| tf.tag_id }
    else
      tags_filtered_by_cookie.map { |t| t.id }
    end
  end

  def stories
    StoryRepository.new(@user, exclude_tags: filtered_tag_ids)
  end

  def page
    p = params[:page].to_i
    if p == 0
      p = 1
    elsif p < 0 || p > (2**32)
      raise ActionController::RoutingError.new("page out of bounds")
    end
    p
  end

  def paginate(scope)
    StoriesPaginator.new(scope, page, @user).get
  end

  def get_from_cache(opts = {}, &block)
    if Rails.env.development? || @user || tags_filtered_by_cookie.any?
      yield
    else
      key = opts.merge(page: page).sort.map { |k, v|
        "#{k}=#{v.to_param}"
      }.join(" ")
      begin
        Rails.cache.fetch("stories #{key}", expires_in: 45, &block)
      rescue Errno::ENOENT => e
        Rails.logger.error "error fetching stories #{key}: #{e}"
        yield
      end
    end
  end
end
