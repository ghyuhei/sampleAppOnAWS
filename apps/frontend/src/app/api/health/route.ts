import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET() {
  return NextResponse.json(
    {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: '@ecs-test/frontend',
      environment: process.env.NODE_ENV,
    },
    { status: 200 }
  )
}
