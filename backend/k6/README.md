# k6 Load Tests

## Prerequisites

```bash
brew install k6
./run-api.sh -d   # start backend
```

Seed at least one restaurant + dish into the DB, then grab their IDs and a valid JWT.

## Running

```bash
# Reactions (100 VUs, 30s)
k6 run --env JWT=<token> --env DISH_ID=<uuid> --env API_URL=http://localhost:8080 01_reactions.js

# Search (50 VUs, 30s)
k6 run --env API_URL=http://localhost:8080 02_search.js

# Restaurant screen (20 VUs, 30s)
k6 run --env JWT=<token> --env RESTAURANT_ID=<uuid> --env API_URL=http://localhost:8080 03_restaurant_screen.js
```

## Targets

| Scenario | VUs | p95 target | p99 target |
|---|---|---|---|
| Reactions | 100 | <200ms | <500ms |
| Search | 50 | <100ms | <200ms |
| Restaurant screen | 20 | <50ms | <100ms |

## If a threshold fails

Run `EXPLAIN ANALYZE` on the slow query from the logs:

```sql
EXPLAIN ANALYZE SELECT ... -- paste slow query here
```

Add missing indexes as a new migration in `backend/migrations/`.
