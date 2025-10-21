require "nokogiri"
require "time"

class BlogPostsController < ApplicationController
  before_action :set_cur_url
  before_action :set_blog_post, only: [:show, :edit, :update, :destroy]
  before_action :require_logged_in_admin, except: [:index, :show]
  helper_method :current_user_admin?

  PER_PAGE = 10
  FEED_LIMIT = 50

  def index
    respond_to do |format|
      format.html do
        @title = "Blog"
        @heading = "Blog"
        @meta_description = "Articles de Journal du hacker : annonces, sélections communautaires et actualités de la plateforme."
        @rss_link = {title: "RSS du blog", href: blog_posts_path(format: :rss)}

        scope = BlogPost.includes(:user).order(published_at: :desc)
        scope = scope.published unless current_user_admin?

        @page = [params[:page].to_i, 1].max
        @blog_posts = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
        @show_more = scope.offset(@page * PER_PAGE).exists?
      end

      format.rss do
        posts = BlogPost.published.includes(:user).limit(FEED_LIMIT)
        options = {
          host: Rails.application.domain,
          protocol: Rails.application.ssl? ? "https" : "http"
        }

        doc = Nokogiri::XML::Document.new
        doc.encoding = "UTF-8"

        rss = Nokogiri::XML::Node.new("rss", doc)
        rss["version"] = "2.0"
        rss["xmlns:content"] = "http://purl.org/rss/1.0/modules/content/"
        doc.add_child(rss)

        channel = Nokogiri::XML::Node.new("channel", doc)
        rss.add_child(channel)

        append_text_node(doc, channel, "title", "Journal du hacker - Blog")
        append_text_node(doc, channel, "link", blog_posts_url(options))
        append_text_node(doc, channel, "description", "Articles et annonces publiés sur le blog du Journal du hacker.")
        append_text_node(doc, channel, "language", "fr-fr")
        append_text_node(doc, channel, "generator", "Journal du hacker")

        if (latest = posts.first)
          append_text_node(doc, channel, "lastBuildDate", latest.published_at&.utc&.rfc2822)
        end

        posts.each do |post|
          post_url = blog_post_url(post, options)

          item = Nokogiri::XML::Node.new("item", doc)
          channel.add_child(item)

          append_text_node(doc, item, "title", post.title)
          append_text_node(doc, item, "link", post_url)

          guid = Nokogiri::XML::Node.new("guid", doc)
          guid["isPermaLink"] = "true"
          guid.content = post_url
          item.add_child(guid)

          append_text_node(doc, item, "pubDate", post.published_at&.utc&.rfc2822)

          description = Nokogiri::XML::Node.new("description", doc)
          description.add_child(Nokogiri::XML::CDATA.new(doc, post.summary(360)))
          item.add_child(description)

          content_node = Nokogiri::XML::Node.new("content:encoded", doc)
          content_node.add_child(Nokogiri::XML::CDATA.new(doc, post.markeddown_body.to_s))
          item.add_child(content_node)
        end

        render xml: doc.to_xml
      end
    end
  end

  def show
    unless @blog_post.published? || current_user_admin?
      raise ActiveRecord::RecordNotFound
    end

    @title = @blog_post.title
    @heading = @blog_post.title
    @meta_description = @blog_post.summary
  end

  def new
    @blog_post = BlogPost.new(published_at: Time.current)
  end

  def create
    @blog_post = BlogPost.new(blog_post_params)
    @blog_post.user = @user

    if @blog_post.save
      flash[:success] = "Article publié."
      redirect_to blog_post_path(@blog_post)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @blog_post.update(blog_post_params)
      flash[:success] = "Article mis à jour."
      redirect_to blog_post_path(@blog_post)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @blog_post.destroy
    flash[:success] = "Article supprimé."
    redirect_to blog_posts_path
  end

  private

  def set_cur_url
    @cur_url = "/blog"
  end

  def set_blog_post
    @blog_post = BlogPost.find_by!(slug: params[:slug])
  end

  def blog_post_params
    params.require(:blog_post).permit(:title, :slug, :body, :published_at, :draft)
  end

  def current_user_admin?
    @user&.is_admin?
  end

  def append_text_node(doc, parent, name, value)
    node = Nokogiri::XML::Node.new(name, doc)
    node.content = value.to_s
    parent.add_child(node)
  end
end
