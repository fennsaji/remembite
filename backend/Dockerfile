# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM rust:1.91-slim-bookworm AS builder

# aws-lc-sys (pulled in by aws-sdk-s3 / rustls) requires cmake + clang
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config cmake clang libclang-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache dependency compilation layer — only re-runs when Cargo.lock changes
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
    && cargo build --release 2>/dev/null || true \
    && rm -rf src

COPY . .
# Touch main.rs so cargo knows sources changed
RUN touch src/main.rs && cargo build --release

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/remembite-backend /usr/local/bin/remembite-backend

EXPOSE 8080

CMD ["remembite-backend"]
