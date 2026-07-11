FROM mcr.microsoft.com/devcontainers/python:3.12

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends git curl unzip gnupg lsb-release \
  && curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends terraform awscli \
  && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
