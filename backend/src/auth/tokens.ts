import { jwtVerify, SignJWT } from "jose";

const algorithm = "HS256";

export const accessTokenTtlSeconds = 15 * 60;

export class TokenService {
  private readonly key: Uint8Array;

  constructor(
    secret: string,
    private readonly ttlSeconds = accessTokenTtlSeconds,
    private readonly now: () => number = () => Math.floor(Date.now() / 1000),
  ) {
    if (secret.length < 32) {
      throw new Error("JWT secret is not configured");
    }
    this.key = new TextEncoder().encode(secret);
  }

  async sign(
    userId: string,
    expiresAtSeconds?: number,
  ): Promise<{ accessToken: string; expiresAt: string }> {
    const issuedAt = this.now();
    const expiresAt = expiresAtSeconds ?? issuedAt + this.ttlSeconds;
    const tokenIssuedAt = expiresAt <= issuedAt ? expiresAt - 1 : issuedAt;
    const accessToken = await new SignJWT({})
      .setProtectedHeader({ alg: algorithm })
      .setSubject(userId)
      .setIssuedAt(tokenIssuedAt)
      .setExpirationTime(expiresAt)
      .sign(this.key);

    return {
      accessToken,
      expiresAt: new Date(expiresAt * 1000).toISOString(),
    };
  }

  async verify(token: string): Promise<string> {
    const { payload } = await jwtVerify(token, this.key, { algorithms: [algorithm] });
    if (!payload.sub) {
      throw new Error("Token subject is missing");
    }
    return payload.sub;
  }
}
