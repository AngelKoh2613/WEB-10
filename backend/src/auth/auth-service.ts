import { AppError } from "../errors/app-error.js";
import {
  dummyPasswordHash,
  hashPassword,
  passwordViolatesPolicy,
  verifyPassword,
} from "./password.js";
import { TokenService } from "./tokens.js";
import {
  DuplicateEmailError,
  toPublicUser,
  type PublicUser,
  type UserRepository,
} from "./user-repository.js";

export type AuthResult = {
  user: PublicUser;
  accessToken: string;
  expiresAt: string;
};

export class AuthService {
  constructor(
    private readonly users: UserRepository,
    private readonly tokens: TokenService,
  ) {}

  async register(email: string, password: string): Promise<AuthResult> {
    if (passwordViolatesPolicy(password, email)) {
      throw new AppError(400, "VALIDATION_ERROR", "La contraseña no cumple la política");
    }

    const passwordHash = await hashPassword(password);
    try {
      const user = await this.users.create({ email, passwordHash });
      const token = await this.tokens.sign(user.id);
      return { user: toPublicUser(user), ...token };
    } catch (error) {
      if (error instanceof DuplicateEmailError) {
        throw new AppError(409, "CONFLICT", "No se pudo completar el registro");
      }
      throw error;
    }
  }

  async login(email: string, password: string): Promise<AuthResult> {
    const user = await this.users.findByEmail(email);
    const passwordHash = user?.passwordHash ?? (await dummyPasswordHash());
    const matches = await verifyPassword(passwordHash, password);
    if (!user || !matches) {
      throw new AppError(401, "INVALID_CREDENTIALS", "Correo o contraseña incorrectos");
    }

    const token = await this.tokens.sign(user.id);
    return { user: toPublicUser(user), ...token };
  }
}
