require "fileutils"
require "nokogiri"
require "securerandom"

module Pluxml
  class BlogPostImporter
    FILENAME_PATTERN = /
      \A
      (?<legacy_id>\d+)\.
      (?<categories>[^.]+)\.
      (?<legacy_author>[^.]+)\.
      (?<timestamp>\d{12})\.
      (?<slug>.+)
      \.xml
      \z
    /x

    Result = Struct.new(:created, :updated, :skipped, keyword_init: true) do
      def increment!(key)
        self[key] += 1
      end
    end

    AUTHOR_MAPPINGS = {
      "001" => {username: "carlchenet"},
      "002" => {username: "Cascador"},
      "003" => {username: "tintouli"},
      "004" => {username: "equipe", email: "blog+equipe@journalduhacker.net", name: "Equipe", is_admin: false}
    }.freeze

    attr_reader :source_articles_dir, :source_medias_dir, :destination_medias_dir

    def initialize(source_root: Rails.root.join("tmp", "blog"),
      destination_medias_dir: Rails.root.join("public", "data", "medias"))
      @source_articles_dir = Pathname(source_root).join("articles")
      @source_medias_dir = Pathname(source_root).join("medias")
      @destination_medias_dir = Pathname(destination_medias_dir)
    end

    def import!(user:)
      raise ArgumentError, "user must be an admin User" unless user.is_a?(User) && user.is_admin?
      raise Errno::ENOENT, "articles directory missing: #{source_articles_dir}" unless source_articles_dir.directory?
      raise Errno::ENOENT, "medias directory missing: #{source_medias_dir}" unless source_medias_dir.directory?

      copy_medias!
      import_articles!(user)
    end

    private

    def copy_medias!
      FileUtils.mkdir_p(destination_medias_dir)

      Dir.glob(source_medias_dir.join("**", "*")).each do |src_path|
        next if File.directory?(src_path)

        relative = Pathname(src_path).relative_path_from(source_medias_dir)
        dest_path = destination_medias_dir.join(relative)
        FileUtils.mkdir_p(dest_path.dirname)

        next if File.exist?(dest_path) && FileUtils.identical?(src_path, dest_path)

        FileUtils.cp(src_path, dest_path)
      end
    end

    def import_articles!(default_user)
      result = Result.new(created: 0, updated: 0, skipped: 0)

      Dir.glob(source_articles_dir.join("*.xml")).sort.each do |file_path|
        attrs = extract_attributes_from(Pathname(file_path))

        blog_post = BlogPost.find_or_initialize_by(slug: attrs[:slug])
        resolved_user = resolve_author(attrs[:legacy_author], default_user)
        blog_post.user = resolved_user
        blog_post.title = attrs[:title]
        blog_post.body = attrs[:body]
        blog_post.published_at = attrs[:published_at]
        blog_post.draft = attrs[:draft]
        blog_post.legacy_identifier = attrs[:legacy_identifier] if attrs[:legacy_identifier]

        if blog_post.new_record? || blog_post.changed?
          BlogPost.record_timestamps = false
          blog_post.created_at ||= attrs[:published_at]
          blog_post.updated_at = attrs[:published_at]
          blog_post.save!
          BlogPost.record_timestamps = true

          key = blog_post.previous_changes.key?("id") ? :created : :updated
          result.increment!(key)
        else
          result.increment!(:skipped)
        end
      rescue => e
        raise "Failed to import #{file_path}: #{e.message}"
      ensure
        BlogPost.record_timestamps = true
      end

      result
    end

    def extract_attributes_from(file_path)
      match = FILENAME_PATTERN.match(file_path.basename.to_s)
      raise ArgumentError, "Unrecognised article filename format: #{file_path}" unless match

      legacy_identifier = match[:legacy_id].to_i
      slug = match[:slug].parameterize
      published_at = parse_timestamp(match[:timestamp])
      categories = match[:categories].split(",")
      draft = categories.include?("draft")

      document = Nokogiri::XML(file_path.read)
      title = document.xpath("//title").text.strip
      chapo = document.xpath("//chapo").text.to_s
      content = document.xpath("//content").text.to_s

      body_html = [chapo, content].map { |section|
        sanitize_html(section)
      }.reject(&:blank?).join("\n\n")

      {
        slug: slug,
        title: title,
        body: body_html,
        published_at: published_at,
        draft: draft,
        legacy_author: match[:legacy_author],
        legacy_identifier: legacy_identifier
      }
    end

    def parse_timestamp(timestamp)
      Time.zone.strptime(timestamp, "%Y%m%d%H%M")
    rescue ArgumentError
      Time.zone.parse(timestamp)
    end

    def sanitize_html(html)
      html.to_s
        .gsub("\r\n", "\n")
        .gsub(%r{src=["']data/medias/}, 'src="/data/medias/')
    end

    def resolve_author(author_code, default_user)
      mapping = AUTHOR_MAPPINGS[author_code]
      return default_user unless mapping

      username = mapping[:username]
      return default_user unless username.present?

      user = User.where("LOWER(username) = ?", username.downcase).first
      return user if user

      email = mapping[:email] || "blog+#{username.downcase}@journalduhacker.net"
      password = SecureRandom.hex(16)

      user = User.new(
        username: username,
        email: email,
        password: password,
        password_confirmation: password
      )
      user.is_admin = mapping.fetch(:is_admin, false)
      user.is_moderator = mapping.fetch(:is_moderator, false)
      user.about = mapping[:name] if mapping[:name]
      user.save!
      user
    rescue => e
      Rails.logger.error "Failed to resolve author #{author_code}: #{e.message}"
      default_user
    end
  end
end
