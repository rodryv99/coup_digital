import { Controller, Get } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { RedisService } from '../redis/redis.service';

@Controller('health')
export class HealthController {
  constructor(
    @InjectDataSource() private dataSource: DataSource,
    private redis: RedisService,
  ) {}

  @Get()
  async check() {
    const checks = {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      services: {
        database: 'unknown',
        redis: 'unknown',
      },
    };

    // Verificar PostgreSQL
    try {
      await this.dataSource.query('SELECT 1');
      checks.services.database = 'ok';
    } catch {
      checks.services.database = 'error';
      checks.status = 'degraded';
    }

    // Verificar Redis
    try {
      await this.redis.set('health:ping', '1', 5);
      const pong = await this.redis.get('health:ping');
      checks.services.redis = pong === '1' ? 'ok' : 'error';
    } catch {
      checks.services.redis = 'error';
      checks.status = 'degraded';
    }

    return checks;
  }
}