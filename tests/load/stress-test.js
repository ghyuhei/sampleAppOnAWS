import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Counter, Trend } from 'k6/metrics';

// カスタムメトリクス
const errorRate = new Rate('errors');
const requestCount = new Counter('requests');
const requestDuration = new Trend('request_duration');

// ストレステスト設定
export const options = {
  stages: [
    { duration: '1m', target: 50 },    // Warm up
    { duration: '2m', target: 100 },   // Increase load
    { duration: '2m', target: 200 },   // Higher load
    { duration: '2m', target: 300 },   // Even higher
    { duration: '2m', target: 400 },   // Stress point
    { duration: '2m', target: 500 },   // Maximum stress
    { duration: '5m', target: 0 },     // Recovery
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000', 'p(99)<2000'],
    http_req_failed: ['rate<0.05'], // 5%以下
    errors: ['rate<0.1'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  const requests = [
    { method: 'GET', url: `${BASE_URL}/api/health` },
    { method: 'GET', url: `${BASE_URL}/` },
  ];

  const responses = http.batch(requests);

  responses.forEach((res) => {
    requestCount.add(1);
    requestDuration.add(res.timings.duration);

    const success = check(res, {
      'status is 200': (r) => r.status === 200,
      'response time < 2s': (r) => r.timings.duration < 2000,
    });

    errorRate.add(!success);
  });

  sleep(1);
}

export function handleSummary(data) {
  return {
    'test-results/stress-test-summary.json': JSON.stringify(data, null, 2),
    'test-results/stress-test-summary.html': htmlReport(data),
    stdout: textSummary(data),
  };
}

function textSummary(data) {
  let summary = '\n';
  summary += '✓ Stress Test Results\n';
  summary += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';

  const metrics = data.metrics;

  summary += 'Performance:\n';
  summary += `  avg: ${metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
  summary += `  p95: ${metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  summary += `  p99: ${metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n`;
  summary += `  max: ${metrics.http_req_duration.values.max.toFixed(2)}ms\n`;

  summary += 'Throughput:\n';
  summary += `  total requests: ${metrics.http_reqs.values.count}\n`;
  summary += `  requests/sec: ${metrics.http_reqs.values.rate.toFixed(2)}\n`;

  summary += `Error Rate: ${(metrics.http_req_failed.values.rate * 100).toFixed(2)}%\n`;
  summary += `VUs: ${metrics.vus.values.max}\n`;

  return summary;
}

function htmlReport(data) {
  const metrics = data.metrics;

  return `
<!DOCTYPE html>
<html>
<head>
  <title>K6 Stress Test Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    h1 { color: #333; }
    .metric { margin: 20px 0; padding: 15px; background: #f5f5f5; border-radius: 5px; }
    .metric h3 { margin-top: 0; color: #666; }
    .value { font-size: 24px; font-weight: bold; color: #0066cc; }
    .threshold-pass { color: #00aa00; }
    .threshold-fail { color: #cc0000; }
  </style>
</head>
<body>
  <h1>K6 Stress Test Report</h1>
  <p>Generated: ${new Date().toISOString()}</p>

  <div class="metric">
    <h3>HTTP Request Duration</h3>
    <p>Average: <span class="value">${metrics.http_req_duration.values.avg.toFixed(2)}ms</span></p>
    <p>P95: <span class="value">${metrics.http_req_duration.values['p(95)'].toFixed(2)}ms</span></p>
    <p>P99: <span class="value">${metrics.http_req_duration.values['p(99)'].toFixed(2)}ms</span></p>
    <p>Max: <span class="value">${metrics.http_req_duration.values.max.toFixed(2)}ms</span></p>
  </div>

  <div class="metric">
    <h3>Throughput</h3>
    <p>Total Requests: <span class="value">${metrics.http_reqs.values.count}</span></p>
    <p>Requests/sec: <span class="value">${metrics.http_reqs.values.rate.toFixed(2)}</span></p>
  </div>

  <div class="metric">
    <h3>Error Rate</h3>
    <p class="${metrics.http_req_failed.values.rate < 0.05 ? 'threshold-pass' : 'threshold-fail'}">
      ${(metrics.http_req_failed.values.rate * 100).toFixed(2)}%
    </p>
  </div>
</body>
</html>
  `;
}
