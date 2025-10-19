import { test, expect } from '@playwright/test'

test.describe('Health Check', () => {
  test('should return OK status', async ({ request }) => {
    const response = await request.get('/api/health')
    expect(response.ok()).toBeTruthy()
    expect(response.status()).toBe(200)

    const body = await response.json()
    expect(body).toHaveProperty('status', 'ok')
    expect(body).toHaveProperty('timestamp')
  })
})

test.describe('Home Page', () => {
  test('should load successfully', async ({ page }) => {
    await page.goto('/')
    await expect(page).toHaveTitle(/Next\.js/)
  })

  test('should have correct viewport', async ({ page }) => {
    await page.goto('/')
    const viewport = page.viewportSize()
    expect(viewport).toBeTruthy()
  })
})
