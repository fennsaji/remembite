// k6 load test: GET /search?q= — 50 concurrent users
// Run: k6 run --env API_URL=http://localhost:8080 02_search.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  scenarios: {
    search: {
      executor: 'constant-vus',
      vus: 50,
      duration: '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<100', 'p(99)<200'],  // stricter — search should be fast
    errors: ['rate<0.01'],
  },
};

const QUERIES = ['biryani', 'butter chicken', 'pizza', 'dosa', 'curry', 'noodle', 'rice'];

export default function () {
  const baseUrl = __ENV.API_URL || 'http://localhost:8080';
  const q = QUERIES[Math.floor(Math.random() * QUERIES.length)];

  const resp = http.get(`${baseUrl}/search?q=${encodeURIComponent(q)}`);

  const ok = check(resp, {
    'status is 200': (r) => r.status === 200,
    'has restaurants key': (r) => {
      try { return JSON.parse(r.body).restaurants !== undefined; }
      catch { return false; }
    },
    'has dishes key': (r) => {
      try { return JSON.parse(r.body).dishes !== undefined; }
      catch { return false; }
    },
  });

  errorRate.add(!ok);
  sleep(0.2);
}
