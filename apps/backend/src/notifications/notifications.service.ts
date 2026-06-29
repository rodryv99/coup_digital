import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private fcmEnabled = false;
  private messaging: any = null;

  constructor(private config: ConfigService) {
    this.initFirebase();
  }

  private initFirebase() {
    const projectId = this.config.get<string>('FCM_PROJECT_ID');
    const clientEmail = this.config.get<string>('FCM_CLIENT_EMAIL');
    const privateKey = this.config.get<string>('FCM_PRIVATE_KEY');

    if (!projectId || !clientEmail || !privateKey) {
      this.logger.warn('FCM no configurado — las notificaciones se loguearán en consola');
      return;
    }

    try {
      const admin = require('firebase-admin');
      if (!admin.apps.length) {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            clientEmail,
            privateKey: privateKey.replace(/\\n/g, '\n'),
          }),
        });
      }
      this.messaging = admin.messaging();
      this.fcmEnabled = true;
      this.logger.log('FCM inicializado correctamente');
    } catch (err: any) {
      this.logger.error(`Error al inicializar FCM: ${err.message}`);
    }
  }

  async sendToToken(fcmToken: string | null, payload: PushPayload): Promise<void> {
    if (!fcmToken) return;

    if (!this.fcmEnabled) {
      this.logger.log(`[PUSH simulado] → ${fcmToken.slice(0, 12)}...: ${payload.title} — ${payload.body}`);
      return;
    }

    try {
      await this.messaging.send({
        token: fcmToken,
        notification: { title: payload.title, body: payload.body },
        data: payload.data ?? {},
      });
    } catch (err: any) {
      this.logger.error(`Error enviando push: ${err.message}`);
    }
  }

  async notifyTurn(fcmToken: string | null, username: string, roomId: string, gameId: string): Promise<void> {
    await this.sendToToken(fcmToken, {
      title: '🎯 Es tu turno',
      body: `${username}, es tu turno en la partida de Coup`,
      data: { type: 'turn', roomId, gameId },
    });
  }

  async notifyReaction(
    fcmToken: string | null, username: string, kind: string, roomId: string, gameId: string,
  ): Promise<void> {
    await this.sendToToken(fcmToken, {
      title: '⚡ Acción requerida',
      body: `${username}, hay ${kind} pendiente en tu partida`,
      data: { type: 'reaction', roomId, gameId },
    });
  }
}