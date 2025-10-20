# Default FROM email for all mailers
ActionMailer::Base.default_options = {
  from: "Journal du hacker <noreply@journalduhacker.net>"
}

smtp_settings = {
  address: ENV.fetch("SMTP_ADDRESS", "127.0.0.1"),
  port: ENV.fetch("SMTP_PORT", "25").to_i,
  domain: ENV.fetch("SMTP_DOMAIN", Rails.application.domain),
  enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true") == "true"
}

# Only add authentication if credentials are provided
if ENV["SMTP_USERNAME"].present? && ENV["SMTP_PASSWORD"].present?
  smtp_settings[:user_name] = ENV["SMTP_USERNAME"]
  smtp_settings[:password] = ENV["SMTP_PASSWORD"]
  smtp_settings[:authentication] = ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym
end

ActionMailer::Base.smtp_settings = smtp_settings
