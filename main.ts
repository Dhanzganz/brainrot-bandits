// Brainrot Bandits — make.fun entry program (Node 22, standard library only).
//
// The grader runs this file from the repository root. It stages the entry's
// payload into the output directory and then asks the vendored make.fun
// helper to describe that payload in a dossier.json the judge can read:
//
//   game.rbxl     the Rojo-built place file
//   PLAY.json     the public play link for the experience
//   src/          every Luau source that Rojo packed into the place
//   screenshots/  the stills the judge sees (copied only when present)
//
// Dot-prefixed names are skipped at every depth while copying, because the
// grader refuses output trees that contain them. The program is fully
// deterministic: no network, no clock, no randomness, and it prints nothing
// when it succeeds.

import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { buildDossier } from "./vendor/makefun-roblox.ts";

// The repository root is wherever this file lives.
const root = dirname(fileURLToPath(import.meta.url));

// The grader points MAKEFUN_OUTPUT_DIR at its own scratch space; the plain
// "/output" default matches how the entry is run by hand.
const out = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";
mkdirSync(out, { recursive: true });

function requireFile(name: string): string {
  const from = join(root, name);
  if (!existsSync(from)) {
    throw new Error(`Brainrot Bandits entry is incomplete: ${name} is missing from ${root}`);
  }
  return from;
}

// PLAY.json is the entry's public face: if it does not name a real
// roblox.com/games/ place, the entry is worthless no matter how well the
// rest stages, so check the link before copying a single byte.
const playDoc: unknown = JSON.parse(readFileSync(requireFile("PLAY.json"), "utf8"));
const playUrl =
  typeof playDoc === "object" && playDoc !== null && "url" in playDoc
    ? (playDoc as { url: unknown }).url
    : undefined;
if (typeof playUrl !== "string" || !/^https:\/\/(www\.)?roblox\.com\/games\/\d+/.test(playUrl)) {
  throw new Error(
    `PLAY.json must name a https://www.roblox.com/games/<place id> URL; got ${JSON.stringify(playUrl)}`,
  );
}

// Single files go across verbatim.
for (const name of ["game.rbxl", "PLAY.json"]) {
  copyFileSync(requireFile(name), join(out, name));
}

// Directories go across recursively, minus anything dot-prefixed: editor
// droppings and VCS internals must never reach the grader's output tree.
const skipDotPrefixed = (src: string): boolean => {
  const base = src.split(/[\\/]/).pop() ?? "";
  return !base.startsWith(".");
};

cpSync(join(root, "src"), join(out, "src"), { recursive: true, filter: skipDotPrefixed });

const shotsFrom = join(root, "screenshots");
if (existsSync(shotsFrom)) {
  cpSync(shotsFrom, join(out, "screenshots"), { recursive: true, filter: skipDotPrefixed });
}

// Finally, describe exactly what was staged. The limits below are the
// bounty's own: dossier text is capped, at most four screenshots are
// embedded, and the place/script budgets keep a runaway build from passing.
// buildDossier reads the staged payload back from the output directory and
// hands back the dossier bytes; writing them out is this program's job.
const dossier = buildDossier(out, {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
});
writeFileSync(join(out, "dossier.json"), dossier);
