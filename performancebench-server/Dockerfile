FROM rust:1.93 AS builder

RUN rustup target add x86_64-unknown-linux-musl
RUN apt-get update && apt-get install -y musl-tools && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy workspace manifests first for dependency caching
COPY Cargo.toml Cargo.lock ./
COPY models/Cargo.toml models/
COPY db/Cargo.toml db/
COPY server/Cargo.toml server/

# Create dummy source files to cache dependency compilation
RUN mkdir -p models/src db/src server/src
RUN echo "" > models/src/lib.rs
RUN echo "" > db/src/lib.rs
RUN echo "fn main() {}" > server/src/main.rs
RUN cargo build --release --target x86_64-unknown-linux-musl || true
RUN rm -f target/x86_64-unknown-linux-musl/release/deps/server*

# Copy actual source and build
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl

FROM alpine:3.21

RUN addgroup -S benchify && adduser -S benchify -G benchify
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/server /usr/local/bin/server
COPY --from=builder /app/migrations /usr/local/bin/migrations
USER benchify
EXPOSE 3000
CMD ["server"]
