// k6 load test: GET /restaurants/:id/dishes (Restaurant Super Screen) — 20 concurrent users
// Run: k6 run --env JWT=<token> --env RESTAURANT_ID=<uuid> --env API_URL=http://localhost:8080 03_restaurant_screen.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  scenarios: {
    restaurant_screen: {
      executor: 'constant-vus',
      vus: 20,
      duration: '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<50', 'p(99)<100'],  // Restaurant screen target: <50ms
    errors: ['rate<0.01'],
  },
};

export default function () {
  if (!__ENV.JWT) throw new Error('JWT env var is required. Pass with --env JWT=<token>');
  if (!__ENV.RESTAURANT_ID) throw new Error('RESTAURANT_ID env var is required. Pass with --env RESTAURANT_ID=<uuid>');

  const jwt = __ENV.JWT;
  const restaurantId = __ENV.RESTAURANT_ID;
  const baseUrl = __ENV.API_URL || 'http://localhost:8080';

  const headers = { 'Authorization': `Bearer ${jwt}` };

  // Simulate loading Restaurant Super Screen: detail + dishes in parallel
  const responses = http.batch([
    { method: 'GET', url: `${baseUrl}/restaurants/${restaurantId}`, params: { headers } },
    { method: 'GET', url: `${baseUrl}/restaurants/${restaurantId}/dishes`, params: { headers } },
  ]);

  const ok = check(responses[0], { 'restaurant detail 200': (r) => r.status === 200 }) &&
             check(responses[1], { 'dishes list 200': (r) => r.status === 200 });

  errorRate.add(!ok);
  sleep(0.5);
}
