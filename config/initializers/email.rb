ActionMailer::Base.smtp_settings = {
  address: ENV.fetch("SMTP_ADDRESS", "127.0.0.1"),
  port: ENV.fetch("SMTP_PORT", "25").to_i,
  domain: ENV.fetch("SMTP_DOMAIN", Rails.application.domain),
  user_name: ENV["SMTP_USERNAME"],
  password: ENV["SMTP_PASSWORD"],
  authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain"),
  enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true") == "true"
}
