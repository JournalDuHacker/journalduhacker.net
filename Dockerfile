# Ruby 2.5.9 est compatible avec Rails 5.2
FROM ruby:2.5.9

# OCI Image labels
LABEL org.opencontainers.image.source=https://github.com/flemzord/journalduhacker.net
LABEL org.opencontainers.image.description="Journal du Hacker - A Hacker News like platform for French-speaking developers"
LABEL org.opencontainers.image.licenses=AGPL

# Install bundler compatible avec Ruby 2.5
RUN gem install bundler -v 2.3.26 --no-document

# Fix Debian Buster archived repositories
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i '/stretch-updates/d' /etc/apt/sources.list

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

# Copy application code
COPY . .

# Update nokogiri to fix build issues, then install all gems
RUN bundle update nokogiri && bundle install --jobs 4 --retry 3

# Expose port 3000
EXPOSE 3000

# Default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
