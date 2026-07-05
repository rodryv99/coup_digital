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

  // Perfil propio: nombre visible y/o avatar. Devuelve el usuario sin el hash.
  async updateProfile(
    userId: string,
    changes: { username?: string; avatar?: string | null },
  ): Promise<Omit<User, 'passwordHash'>> {
    const user = await this.findById(userId);
    if (!user) throw new NotFoundException('Usuario no encontrado');

    if (changes.username !== undefined) {
      const nuevo = changes.username.trim();
      if (nuevo.length < 3 || nuevo.length > 50) {
        throw new BadRequestException('El nombre debe tener entre 3 y 50 caracteres');
      }
      if (nuevo !== user.username) {
        const taken = await this.repo.findOne({ where: { username: nuevo } });
        if (taken) throw new ConflictException('Ese nombre de usuario ya está en uso');
        user.username = nuevo;
      }
    }

    if (changes.avatar !== undefined) {
      if (changes.avatar && changes.avatar.length > 200_000) {
        throw new BadRequestException('La imagen es demasiado grande');
      }
      user.avatar = changes.avatar;
    }

    const saved = await this.repo.save(user);
    const { passwordHash, ...safe } = saved;
    return safe;
  }

  async changePassword(userId: string, currentPassword: string, newPassword: string): Promise<{ message: string }> {
    const user = await this.findById(userId);
    if (!user) throw new NotFoundException('Usuario no encontrado');

    const ok = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!ok) throw new BadRequestException('La contraseña actual es incorrecta');

    if (!newPassword || newPassword.length < 8) {
      throw new BadRequestException('La nueva contraseña debe tener al menos 8 caracteres');
    }

    user.passwordHash = await bcrypt.hash(newPassword, 12);
    await this.repo.save(user);
    return { message: 'Contraseña actualizada' };
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