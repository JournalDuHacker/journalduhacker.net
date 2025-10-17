require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Lobsters
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks monkey.rb])

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W[#{config.root}/extras]

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    config.time_zone = "Europe/Paris"

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.default_locale = :fr

    # Raise an exception when using mass assignment with unpermitted attributes
    config.action_controller.action_on_unpermitted_parameters = :raise

    config.cache_store = :file_store, "#{config.root}/tmp/cache/"

    config.exceptions_app = routes

    # Rails 6.0+ requires permitted classes for YAML deserialization
    # Required for activerecord-typedstore gem
    config.active_record.yaml_column_permitted_classes ||= []
    config.active_record.yaml_column_permitted_classes += [Symbol, Date, Time, DateTime, ActiveSupport::HashWithIndifferentAccess, BigDecimal]

    config.after_initialize do
      load "#{Rails.root}/lib/monkey.rb"
    end
  end
end

# define site name and domain to be used globally, should be overridden in a
# local file such as config/initializers/production.rb
class << Rails.application
  def allow_invitation_requests?
    true
  end

  def domain
    "www.journalduhacker.net"
  end

  def name
    "Journal du hacker"
  end

  def root_url
    Rails.application.routes.url_helpers.root_url({
      host: Rails.application.domain,
      protocol: Rails.application.ssl? ? "https" : "http"
    })
  end

  # used as mailing list prefix and countinual prefix, cannot have spaces
  def shortname
    name.downcase.gsub(/[^a-z]/, "")
  end

  # whether absolute URLs should include https (does not require that
  # config.force_ssl be on)
  def ssl?
    true
  end
end
