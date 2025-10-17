# This file is copied to spec/ when you run 'rails generate rspec:install'

# SimpleCov configuration for code coverage
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"

  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Helpers", "app/helpers"
  add_group "Mailers", "app/mailers"
  add_group "Jobs", "app/jobs"

  track_files "{app,lib}/**/*.rb"
end

# Monkey patch for Ruby 3.x compatibility with Machinist
# In Ruby 3.x, Fixnum was merged into Integer
unless defined?(Fixnum) # rubocop:disable Lint/UnifiedInteger
  Fixnum = Integer # rubocop:disable Lint/UnifiedInteger
end

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../../config/environment", __FILE__)
require "rspec/rails"

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec::Expectations.configuration.on_potential_false_positives = :nothing

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  config.infer_spec_type_from_file_location!

  # Create required tags once before the entire test suite
  config.before(:suite) do
    Tag.destroy_all
    Tag.create!(tag: "tag1", description: "Tag 1")
    Tag.create!(tag: "tag2", description: "Tag 2")
  end
end
