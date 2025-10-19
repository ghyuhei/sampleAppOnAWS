import http from 'k6/http';
import { check, sleep } from 'k6';

// スパイクテスト: 急激な負荷増加に対する耐性をテスト
export const options = {
  stages: [
    { duration: '30s', target: 10 },   // 通常負荷
    { duration: '10s', target: 500 },  // 急激にスパイク
    { duration: '1m', target: 500 },   // スパイク維持
    { duration: '10s', target: 10 },   // 急激に減少
    { duration: '30s', target: 0 },    // クールダウン
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // スパイク時は緩めの閾値
    http_req_failed: ['rate<0.1'],     // 10%以下
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  const res = http.get(`${BASE_URL}/api/health`);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time acceptable': (r) => r.timings.duration < 3000,
  });

  sleep(0.5); // スパイクテストなので短いスリープ
}
