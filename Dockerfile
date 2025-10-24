# Ruby 3.4.7 est compatible avec Rails 8.1
FROM ruby:3.4.7

# OCI Image labels
LABEL org.opencontainers.image.source=https://github.com/journalduhacker/journalduhacker.net
LABEL org.opencontainers.image.description="Journal du Hacker - A Hacker News like platform for French-speaking developers"
LABEL org.opencontainers.image.licenses=AGPL

# Install bundler
RUN gem install bundler --no-document

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y \
    default-libmysqlclient-dev \
    libxml2-dev \
    libxslt1-dev \
    nodejs \
    default-mysql-client \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock first (better caching)
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install --jobs 4 --retry 3

# Now copy the rest of the application code
COPY . .

# Expose port 3000
EXPOSE 3000

# Default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
