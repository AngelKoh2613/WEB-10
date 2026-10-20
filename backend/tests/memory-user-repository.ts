import { randomUUID } from "node:crypto";
import {
  DuplicateEmailError,
  type StoredUser,
  type UserRepository,
} from "../src/auth/user-repository.js";

export class MemoryUserRepository implements UserRepository {
  readonly users: StoredUser[] = [];
  failOnCreate: Error | undefined;

  async create(input: { email: string; passwordHash: string }): Promise<StoredUser> {
    if (this.failOnCreate) {
      throw this.failOnCreate;
    }
    if (this.users.some((user) => user.email === input.email)) {
      throw new DuplicateEmailError();
    }

    const now = new Date();
    const user: StoredUser = {
      id: randomUUID(),
      email: input.email,
      passwordHash: input.passwordHash,
      createdAt: now,
      updatedAt: now,
    };
    this.users.push(user);
    return user;
  }

  async findByEmail(email: string): Promise<StoredUser | null> {
    return this.users.find((user) => user.email === email) ?? null;
  }
}
