namespace :blog do
  desc "Import PluXML blog archive from tmp/blog into BlogPost records"
  task import: :environment do
    require Rails.root.join("lib", "pluxml", "blog_post_importer")

    admin = User.where(is_admin: true).order(:id).first
    raise "No admin user found to attach blog posts" unless admin

    importer = Pluxml::BlogPostImporter.new
    result = importer.import!(user: admin)

    puts "Blog import finished: #{result.created} created, #{result.updated} updated, #{result.skipped} skipped."
  end
end
