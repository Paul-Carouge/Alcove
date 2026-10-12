import { describe, expect, it } from 'vitest';
import { generatePassword } from './api';

describe('generatePassword', () => {
	it('is long, grouped and unambiguous', () => {
		const p = generatePassword();
		expect(p).toMatch(/^[a-zA-Z2-9]{4}(-[a-zA-Z2-9]{4}){3}$/);
		expect(p).not.toMatch(/[0O1lI]/);
		expect(generatePassword()).not.toBe(p);
	});
});
