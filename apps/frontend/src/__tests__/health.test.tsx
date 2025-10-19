import { describe, it, expect } from 'vitest'

describe('Health Check', () => {
  it('should return 200 for health endpoint', async () => {
    const response = await fetch('http://localhost:3000/api/health')
    expect(response.status).toBe(200)
  })
})

describe('Basic Math', () => {
  it('should add numbers correctly', () => {
    expect(1 + 1).toBe(2)
  })
})
