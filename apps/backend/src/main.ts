import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });

  // Seguridad de cabeceras HTTP
  app.use(helmet());

  // CORS — en producción restringir origin a los dominios reales
  app.enableCors({
    origin: process.env.CORS_ORIGIN?.split(',') ?? '*',
    credentials: true,
  });

  app.setGlobalPrefix('api');

  // Validación global
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  // Manejo centralizado de errores
  app.useGlobalFilters(new AllExceptionsFilter());

  // Logging de peticiones
  app.useGlobalInterceptors(new LoggingInterceptor());

  // Cierre ordenado (libera conexiones a DB/Redis al apagar)
  app.enableShutdownHooks();

  const port = process.env.PORT ?? 3000;
  await app.listen(port);

  Logger.log(`🚀 Backend corriendo en http://localhost:${port}/api`, 'Bootstrap');
}
bootstrap();