/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  rootDir: ".",
  testMatch: ["<rootDir>/src/__tests__/**/*.test.ts"],
  testTimeout: 20000,
  // @firebase/rules-unit-testing keeps a gRPC/websocket handle open past
  // testEnv.cleanup() — cosmetic, not a leak in our own test code.
  forceExit: true,
  transform: {
    "^.+\\.ts$": ["ts-jest", {tsconfig: "tsconfig.jest.json"}],
  },
};
