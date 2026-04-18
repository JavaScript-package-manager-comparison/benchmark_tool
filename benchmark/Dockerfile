FROM node:22-bookworm

RUN apt-get update && apt-get install -y \
    git curl ca-certificates gnupg jq build-essential unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN . "$HOME/.cargo/env" && cargo install hyperfine

COPY . /app
WORKDIR /app
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]