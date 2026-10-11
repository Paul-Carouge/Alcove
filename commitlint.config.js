// Conventional Commits: <type>(<scope>): <subject>
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [
      2,
      'always',
      ['server', 'web', 'mobile', 'desktop', 'api-spec', 'design-tokens', 'deploy', 'docs', 'ci', 'deps', 'release']
    ],
    'body-max-line-length': [1, 'always', 100]
  }
};
