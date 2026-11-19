/**
 * Configures Husky Git hooks in writable local checkouts via `pnpm install` or `pnpm prepare:husky`.
 * Skips execution in CI, when `HUSKY=0`, during pack/publish, or when `.git` is unavailable/unwritable.
 */
import { access } from "node:fs/promises";
import { constants } from "node:fs";
import { spawnSync } from "node:child_process";

const skipCommands = new Set([
  "pack",
  "publish",
]);
const npmCommand = process.env.npm_command;

if (
  process.env.CI === "true" ||
  process.env.HUSKY === "0" ||
  skipCommands.has(npmCommand ?? "")
) {
  process.exit(0);
}

try {
  const gitDir = spawnSync(
    "git",
    [
      "rev-parse",
      "--git-dir",
    ],
    {
      encoding: "utf8",
    },
  );

  if (gitDir.status !== 0) {
    process.exit(0);
  }

  await access(gitDir.stdout.trim(), constants.W_OK);
} catch {
  process.exit(0);
}

const result = spawnSync("husky", {
  stdio: "inherit",
  shell: true,
});

process.exit(result.status ?? 1);
