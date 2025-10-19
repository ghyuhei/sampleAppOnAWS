import { FastifyPluginAsync } from 'fastify';

export const healthRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.get('/health', async (request, reply) => {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    };
  });

  fastify.get('/ready', async (request, reply) => {
    // Add readiness checks here (DB, external services, etc.)
    return {
      status: 'ready',
      timestamp: new Date().toISOString(),
    };
  });
};
