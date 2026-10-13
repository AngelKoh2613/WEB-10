import { getPrismaClient } from "../data/prisma-client.js";
import {
  DuplicateEmailError,
  isUniqueConstraintError,
  type StoredUser,
  type UserRepository,
} from "./user-repository.js";

export class PrismaUserRepository implements UserRepository {
  async create(input: { email: string; passwordHash: string }): Promise<StoredUser> {
    try {
      return await getPrismaClient().user.create({ data: input });
    } catch (error) {
      if (isUniqueConstraintError(error)) {
        throw new DuplicateEmailError();
      }
      throw error;
    }
  }

  async findByEmail(email: string): Promise<StoredUser | null> {
    return getPrismaClient().user.findUnique({ where: { email } });
  }
}
