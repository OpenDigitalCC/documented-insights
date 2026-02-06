# Dockerfile.perl
FROM debian:bookworm-slim

# Install Perl, Pandoc, LaTeX and required tools
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
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-latex-extra && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["tail", "-f", "/dev/null"]

