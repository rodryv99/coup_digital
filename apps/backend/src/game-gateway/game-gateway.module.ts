import { Module } from '@nestjs/common';
import { GameGateway } from './game.gateway';
import { RoomsModule } from '../rooms/rooms.module';
import { GameModule } from '../game/game.module';

@Module({
  imports: [RoomsModule, GameModule],
  providers: [GameGateway],
})
export class GameGatewayModule {}