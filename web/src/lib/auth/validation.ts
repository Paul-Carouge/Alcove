export const MIN_PASSWORD_LENGTH = 10;

// Pragmatic check; the server is the authority.
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const isEmail = (value: string) => EMAIL.test(value.trim());
