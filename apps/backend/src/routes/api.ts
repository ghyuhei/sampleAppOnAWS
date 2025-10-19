import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

const userSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

export const apiRoutes: FastifyPluginAsync = async (fastify) => {
  // GET /api/hello
  fastify.get('/hello', async (request, reply) => {
    return {
      message: 'Hello from TypeScript backend!',
      timestamp: new Date().toISOString(),
    };
  });

  // POST /api/users (example with validation)
  fastify.post('/users', async (request, reply) => {
    try {
      const body = userSchema.parse(request.body);

      // Here you would save to database
      return {
        success: true,
        data: {
          id: Math.random().toString(36).substr(2, 9),
          ...body,
          createdAt: new Date().toISOString(),
        },
      };
    } catch (error) {
      if (error instanceof z.ZodError) {
        reply.code(400);
        return {
          success: false,
          error: 'Validation failed',
          details: error.errors,
        };
      }
      throw error;
    }
  });

  // GET /api/users/:id (example)
  fastify.get('/users/:id', async (request, reply) => {
    const { id } = request.params as { id: string };

    // Here you would fetch from database
    return {
      success: true,
      data: {
        id,
        name: 'Sample User',
        email: 'user@example.com',
      },
    };
  });
};
