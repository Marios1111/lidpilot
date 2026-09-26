import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const project = resolve(here, "..");
const story = JSON.parse(await readFile(resolve(project, "story.json"), "utf8"));
let expectedFrom = 0;
for (const scene of story) {
  if (scene.from !== expectedFrom || !Number.isInteger(scene.duration) || scene.duration <= 0) {
    throw new Error(`Invalid film timeline at scene ${scene.id}`);
  }
  expectedFrom += scene.duration;
}
if (expectedFrom !== 1020) {
  throw new Error(`Expected a 34-second film (1020 frames), found ${expectedFrom} frames`);
}

const timecode = (frames) => {
  const totalMilliseconds = Math.round((frames / 30) * 1000);
  const hours = Math.floor(totalMilliseconds / 3_600_000);
  const minutes = Math.floor((totalMilliseconds % 3_600_000) / 60_000);
  const seconds = Math.floor((totalMilliseconds % 60_000) / 1000);
  const milliseconds = totalMilliseconds % 1000;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}.${String(milliseconds).padStart(3, "0")}`;
};

const vtt = [
  "WEBVTT",
  "",
  ...story.flatMap((scene) => [
    `${timecode(scene.from)} --> ${timecode(scene.from + scene.duration)}`,
    scene.caption,
    "",
  ]),
].join("\n");

const transcript = [
  "LidPilot — product film transcript",
  "",
  ...story.flatMap((scene) => [
    `${timecode(scene.from).slice(3, 8)}–${timecode(scene.from + scene.duration).slice(3, 8)}`,
    scene.caption,
    "",
  ]),
].join("\n");

await writeFile(resolve(project, "web/lidpilot-captions.vtt"), vtt, "utf8");
await writeFile(resolve(project, "web/lidpilot-transcript.txt"), transcript, "utf8");
console.log("Wrote web/lidpilot-captions.vtt and web/lidpilot-transcript.txt from story.json");
