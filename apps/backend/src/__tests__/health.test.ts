import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { build } from '../app'
import type { FastifyInstance } from 'fastify'

describe('Health Check API', () => {
  let app: FastifyInstance

  beforeAll(async () => {
    app = await build()
    await app.ready()
  })

  afterAll(async () => {
    await app.close()
  })

  it('GET /health should return 200', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/health',
    })

    expect(response.statusCode).toBe(200)
    expect(response.json()).toEqual({
      status: 'ok',
      timestamp: expect.any(String),
    })
  })

  it('GET /health should have correct content-type', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/health',
    })

    expect(response.headers['content-type']).toContain('application/json')
  })
})
