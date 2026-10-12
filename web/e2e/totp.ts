import { createHmac } from 'node:crypto';

const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function base32(secret: string): Buffer {
	let bits = '';
	for (const c of secret.replace(/=+$/, '').toUpperCase()) {
		bits += ALPHABET.indexOf(c).toString(2).padStart(5, '0');
	}
	const bytes = bits.match(/.{8}/g) ?? [];
	return Buffer.from(bytes.map((b) => parseInt(b, 2)));
}

/** RFC 6238 TOTP (SHA-1, 6 digits, 30 s), `offset` steps from now. */
export function totpCode(secret: string, offset = 0, now = Date.now()): string {
	const counter = Math.floor(now / 1000 / 30) + offset;
	const msg = Buffer.alloc(8);
	msg.writeBigUInt64BE(BigInt(counter));
	const h = createHmac('sha1', base32(secret)).update(msg).digest();
	const o = h[h.length - 1]! & 0xf;
	const bin = (h.readUInt32BE(o) & 0x7fffffff) % 1_000_000;
	return bin.toString().padStart(6, '0');
}
