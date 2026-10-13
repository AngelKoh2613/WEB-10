import argon2 from "argon2";

const hashOptions = {
  type: argon2.argon2id,
  memoryCost: 19456,
  timeCost: 2,
  parallelism: 1,
} as const;

let dummyHash: Promise<string> | undefined;

export function passwordViolatesPolicy(password: string, email: string): boolean {
  if (password.length < 10 || password.length > 128) {
    return true;
  }
  if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
    return true;
  }
  return password.toLowerCase() === email.toLowerCase();
}

export async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, hashOptions);
}

export async function verifyPassword(passwordHash: string, password: string): Promise<boolean> {
  try {
    return await argon2.verify(passwordHash, password);
  } catch {
    return false;
  }
}

export function dummyPasswordHash(): Promise<string> {
  dummyHash ??= hashPassword("dummy-password-not-a-credential");
  return dummyHash;
}
