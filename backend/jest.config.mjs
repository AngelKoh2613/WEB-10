export default {
  testEnvironment: "node",
  extensionsToTreatAsEsm: [".ts"],
  moduleNameMapper: {
    "^(\\.{1,2}/.*)\\.js$": "$1",
  },
  transform: {
    "^.+\\.ts$": [
      "ts-jest",
      {
        useESM: true,
        tsconfig: {
          module: "Node16",
          moduleResolution: "Node16",
          esModuleInterop: true,
          strict: true,
          isolatedModules: true,
          types: ["jest", "node"],
        },
      },
    ],
  },
  testMatch: ["<rootDir>/tests/**/*.test.ts"],
  clearMocks: true,
};
