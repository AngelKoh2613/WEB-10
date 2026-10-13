export type StoredUser = {
  id: string;
  email: string;
  passwordHash: string;
  createdAt: Date;
  updatedAt: Date;
};

export type PublicUser = {
  id: string;
  email: string;
};

export class DuplicateEmailError extends Error {
  constructor() {
    super("Duplicate email");
    this.name = "DuplicateEmailError";
  }
}

export interface UserRepository {
  create(input: { email: string; passwordHash: string }): Promise<StoredUser>;
  findByEmail(email: string): Promise<StoredUser | null>;
}

export function isUniqueConstraintError(error: unknown): boolean {
  return typeof error === "object" && error !== null && "code" in error && error.code === "P2002";
}

export function toPublicUser(user: StoredUser): PublicUser {
  return { id: user.id, email: user.email };
}
