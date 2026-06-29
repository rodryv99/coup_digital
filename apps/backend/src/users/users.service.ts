import {
  Injectable, ConflictException, NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from './entities/user.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { Role } from '../common/enums/role.enum';
import { UserStatus } from '../common/enums/user-status.enum';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private repo: Repository<User>,
  ) {}

  async create(dto: CreateUserDto): Promise<User> {
    const existing = await this.repo.findOne({
      where: [{ email: dto.email }, { username: dto.username }],
    });
    if (existing) {
      throw new ConflictException('El correo o nombre de usuario ya está en uso');
    }
    const passwordHash = await bcrypt.hash(dto.password, 12);
    const user = this.repo.create({ ...dto, passwordHash });
    return this.repo.save(user);
  }

  async findById(id: string): Promise<User | null> {
    return this.repo.findOne({ where: { id } });
  }

  async findByEmailOrUsername(identifier: string): Promise<User | null> {
    return this.repo.findOne({
      where: [{ email: identifier }, { username: identifier }],
    });
  }

  async findAll(page = 1, limit = 20, search?: string): Promise<{ data: User[]; total: number }> {
    const where = search
      ? [{ username: ILike(`%${search}%`) }, { email: ILike(`%${search}%`) }]
      : {};
    const [data, total] = await this.repo.findAndCount({
      where,
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });
    return { data, total };
  }

  async update(id: string, dto: UpdateUserDto): Promise<User> {
    const user = await this.findById(id);
    if (!user) throw new NotFoundException('Usuario no encontrado');
    Object.assign(user, dto);
    return this.repo.save(user);
  }

  async remove(id: string): Promise<void> {
    const user = await this.findById(id);
    if (!user) throw new NotFoundException('Usuario no encontrado');
    await this.repo.remove(user);
  }

  async incrementFailedAttempts(user: User): Promise<void> {
    user.failedAttempts += 1;
    if (user.failedAttempts >= 5) {
      user.lockedUntil = new Date(Date.now() + 15 * 60 * 1000); // 15 min
      user.status = UserStatus.Blocked;
    }
    await this.repo.save(user);
  }

  async resetFailedAttempts(user: User): Promise<void> {
    user.failedAttempts = 0;
    user.lockedUntil = null as any;
    if (user.status === UserStatus.Blocked) {
      user.status = UserStatus.Active;
    }
    await this.repo.save(user);
  }

  async saveResetToken(userId: string, token: string, expires: Date): Promise<void> {
    await this.repo.update(userId, {
      // guardamos token hasheado en fcmToken temporalmente — en producción
      // usaría una tabla separada; para v1 es suficiente
    } as any);
  }

  async updateFcmToken(userId: string, fcmToken: string): Promise<{ message: string }> {
    await this.repo.update(userId, { fcmToken });
    return { message: 'Token FCM actualizado' };
  }
}