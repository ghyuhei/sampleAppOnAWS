import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// カスタムメトリクス
const errorRate = new Rate('errors');
const healthCheckDuration = new Trend('health_check_duration');

// テスト設定
export const options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp up
    { duration: '1m', target: 50 },    // Stay at 50 users
    { duration: '30s', target: 100 },  // Spike to 100 users
    { duration: '1m', target: 100 },   // Stay at 100 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'], // 95%が500ms以下、99%が1秒以下
    http_req_failed: ['rate<0.01'],                 // エラー率1%以下
    errors: ['rate<0.1'],                           // カスタムエラー率10%以下
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  // Health Check
  const healthRes = http.get(`${BASE_URL}/api/health`);

  const healthCheckSuccess = check(healthRes, {
    'health check status is 200': (r) => r.status === 200,
    'health check has status field': (r) => JSON.parse(r.body).status === 'ok',
    'health check response time < 500ms': (r) => r.timings.duration < 500,
  });

  errorRate.add(!healthCheckSuccess);
  healthCheckDuration.add(healthRes.timings.duration);

  sleep(1);
}

export function handleSummary(data) {
  return {
    'test-results/load-test-summary.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, options = {}) {
  const indent = options.indent || '';
  const enableColors = options.enableColors || false;

  let summary = '\n';
  summary += `${indent}✓ Health Check Load Test Results\n`;
  summary += `${indent}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`;

  const metrics = data.metrics;

  summary += `${indent}HTTP Req Duration:\n`;
  summary += `${indent}  avg: ${metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
  summary += `${indent}  p95: ${metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  summary += `${indent}  p99: ${metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n`;

  summary += `${indent}Requests:\n`;
  summary += `${indent}  total: ${metrics.http_reqs.values.count}\n`;
  summary += `${indent}  rate: ${metrics.http_reqs.values.rate.toFixed(2)}/s\n`;

  summary += `${indent}Error Rate: ${(metrics.http_req_failed.values.rate * 100).toFixed(2)}%\n`;

  return summary;
}
