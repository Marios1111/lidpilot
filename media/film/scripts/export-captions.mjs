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
  for (const cue of scene.captionCues ?? []) {
    if (
      !Number.isInteger(cue.from) ||
      !Number.isInteger(cue.duration) ||
      cue.duration <= 0 ||
      cue.from < scene.from ||
      cue.from + cue.duration > scene.from + scene.duration ||
      typeof cue.text !== "string" ||
      cue.text.trim() === ""
    ) {
      throw new Error(`Invalid caption cue in scene ${scene.id}`);
    }
  }
  expectedFrom += scene.duration;
}
if (expectedFrom !== 1260) {
  throw new Error(`Expected a 42-second film (1260 frames), found ${expectedFrom} frames`);
}

const timecode = (frames) => {
  const totalMilliseconds = Math.round((frames / 30) * 1000);
  const hours = Math.floor(totalMilliseconds / 3_600_000);
  const minutes = Math.floor((totalMilliseconds % 3_600_000) / 60_000);
  const seconds = Math.floor((totalMilliseconds % 60_000) / 1000);
  const milliseconds = totalMilliseconds % 1000;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}.${String(milliseconds).padStart(3, "0")}`;
};

const cues = story.flatMap((scene) => {
  if (scene.captionCues) return scene.captionCues;
  return scene.caption ? [{ from: scene.from, duration: scene.duration, text: scene.caption }] : [];
});

const vtt = [
  "WEBVTT",
  "",
  ...cues.flatMap((cue) => [
    `${timecode(cue.from)} --> ${timecode(cue.from + cue.duration)}`,
    cue.text,
    "",
  ]),
].join("\n");

const transcript = [
  "LidPilot — product film transcript",
  "",
  ...cues.flatMap((cue) => [
    `${timecode(cue.from).slice(3, 8)}–${timecode(cue.from + cue.duration).slice(3, 8)}`,
    cue.text,
    "",
  ]),
].join("\n");

await writeFile(resolve(project, "web/lidpilot-captions.vtt"), vtt, "utf8");
await writeFile(resolve(project, "web/lidpilot-transcript.txt"), transcript, "utf8");
console.log("Wrote web/lidpilot-captions.vtt and web/lidpilot-transcript.txt from story.json");
