# Backend

## Reset local database

Wipes all data and re-applies migrations from scratch:

```bash
./run-api.sh down
docker volume rm remembite_postgres_data
./run-api.sh
```

Migrations run automatically on startup via `sqlx::migrate!()` — no manual step needed.

---

# Backend Tests

## Non-DB tests (run instantly, no setup needed)

```bash
cargo test
```

27 tests covering: JWT security, rate limiting, access control, AI failure handling, worker mocks.

## DB-backed tests (SQL injection + abuse detection)

Requires a running Postgres instance with migrations applied.

```bash
# Option A — use the dev stack
./run-api.sh -d   # from project root; starts postgres on localhost:5432

TEST_DATABASE_URL=postgres://postgres:postgres@localhost:5432/remembite \
  cargo test -- --include-ignored

# Option B — separate test DB
sqlx migrate run --database-url postgres://user:pass@localhost:5432/remembite_test
TEST_DATABASE_URL=postgres://user:pass@localhost:5432/remembite_test \
  cargo test -- --include-ignored
```

Install `sqlx-cli` once if needed: `cargo install sqlx-cli --no-default-features --features postgres`

## k6 Load Tests

Requires a running backend (`./run-api.sh -d`) and seeded data. See [`k6/README.md`](k6/README.md).

## Specific test suites

```bash
cargo test auth::jwt_tests              # JWT security (7 tests)
cargo test middleware::rate_limit       # Rate limiting (5 tests)
cargo test routes::export::access_control  # Access control (3 tests)
cargo test jobs::worker_tests           # AI failure handling (2 tests)
```
