// k6 load test: POST /dishes/:id/reactions — 100 concurrent users
// Run: k6 run --env JWT=<token> --env DISH_ID=<uuid> --env API_URL=http://localhost:8080 01_reactions.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  scenarios: {
    reactions: {
      executor: 'constant-vus',
      vus: 100,
      duration: '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<200', 'p(99)<500'],
    errors: ['rate<0.01'],  // <1% error rate
  },
};

const REACTIONS = ['so_yummy', 'tasty', 'pretty_good', 'meh', 'never_again'];

export default function () {
  if (!__ENV.JWT) throw new Error('JWT env var is required. Pass with --env JWT=<token>');
  if (!__ENV.DISH_ID) throw new Error('DISH_ID env var is required. Pass with --env DISH_ID=<uuid>');

  const jwt = __ENV.JWT;
  const dishId = __ENV.DISH_ID;
  const baseUrl = __ENV.API_URL || 'http://localhost:8080';

  const reaction = REACTIONS[Math.floor(Math.random() * REACTIONS.length)];

  const resp = http.post(
    `${baseUrl}/dishes/${dishId}/reactions`,
    JSON.stringify({ reaction }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${jwt}`,
      },
    }
  );

  const ok = check(resp, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });

  errorRate.add(!ok);
  sleep(0.1);
}
