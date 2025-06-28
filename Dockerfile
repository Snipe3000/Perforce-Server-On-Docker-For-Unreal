# Use Ubuntu 24.04 (Noble Numbat) as the base image
ARG P4_BASEIMAGE=ubuntu:24.04
FROM $P4_BASEIMAGE AS perforce-base
MAINTAINER Van Ferguson

ENV container docker

# Install required system dependencies, including gnupg for handling GPG keys
RUN apt-get update && apt-get install -y \
    cron \
    tar \
    gzip \
    curl \
    openssl \
    sudo \
    debianutils \
    gnupg2 \
    lsb-release && \
    rm -rf /var/lib/apt/lists/*

# Download and install the Perforce GPG key directly into the APT keyring
RUN curl -fsSL https://package.perforce.com/perforce.pubkey | gpg --dearmor -o /usr/share/keyrings/perforce-archive-keyring.gpg

# Add Perforce repository and ensure it's signed with the correct key
RUN echo "deb [signed-by=/usr/share/keyrings/perforce-archive-keyring.gpg] https://package.perforce.com/apt/ubuntu noble release" > /etc/apt/sources.list.d/perforce.list

# Update package lists and install Perforce server and CLI
RUN apt-get update && \
    apt-get install -y p4-server p4-cli && \
    rm -rf /var/lib/apt/lists/*

# Install necessary utilities like gosu, tini, and s6-overlay with updated download links
RUN curl -fsSL https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64 -o /usr/local/bin/gosu \
    && curl -fsSL https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64.asc -o /usr/local/bin/gosu.asc \
    && gpg --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true


# Make sure the run.sh script is executable
ADD ./run.sh /
RUN chmod +x /run.sh

# Convert Windows line endings (CRLF) to Unix line endings (LF) for run.sh
RUN sed -i 's/\r//' /run.sh

# Use /run.sh as the entry point to start the container
ENTRYPOINT ["/run.sh"]

FROM perforce-base AS perforce-server
MAINTAINER Van Ferguson

# Use the same P4_VERSION build argument
ARG P4_VERSION=2025.1

# Install Perforce server and CLI with the version from the build argument
RUN apt-get update && \
    apt-get install -y p4-server p4-cli && \
    rm -rf /var/lib/apt/lists/*
	

EXPOSE 1666
ENV NAME p4depot
ENV P4CONFIG .p4config
ENV DATAVOLUME /data
ENV P4PORT 1666
ENV P4USER p4admin
VOLUME ["$DATAVOLUME"]

ADD ./p4-users.txt /root/
ADD ./p4-groups.txt /root/
ADD ./p4-protect.txt /root/
ADD ./typemap.txt /root/

ADD ./setup-perforce.sh /usr/local/bin/
RUN sed -i 's/\r//' /usr/local/bin/setup-perforce.sh
