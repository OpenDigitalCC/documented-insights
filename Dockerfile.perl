# Dockerfile.perl
FROM debian:bookworm-slim

# Install Perl and required tools
RUN apt-get update && \
    apt-get install -y \
    perl \
    libdbi-perl \
    libdbd-pg-perl \
    libtime-hires-perl \
    libjson-perl \
    liblwp-protocol-https-perl \
    libwww-perl \
    poppler-utils \
    pandoc \
    make \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Keep container running
CMD ["tail", "-f", "/dev/null"]
