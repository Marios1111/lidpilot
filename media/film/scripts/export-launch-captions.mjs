import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const project = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const story = JSON.parse(
  await readFile(resolve(project, "story-launch-candidate.json"), "utf8"),
);
const output = resolve(project, process.argv[2] ?? "out/launch-candidate");
let nextFrame = 0;
for (const scene of story.scenes) {
  if (
    scene.from !== nextFrame ||
    !Number.isInteger(scene.duration) ||
    scene.duration <= 0
  ) {
    throw new Error(`Invalid launch timeline at scene ${scene.id}`);
  }
  nextFrame += scene.duration;
}
if (
  story.fps !== 30 ||
  story.durationInFrames !== 1230 ||
  nextFrame !== story.durationInFrames
) {
  throw new Error(
    "The take 2 launch candidate must contain exactly 1230 frames at 30 fps",
  );
}
if (
  story.narration.from / story.fps + story.narration.decodedDurationSeconds >
  nextFrame / story.fps
) {
  throw new Error("Narration exceeds the launch candidate duration");
}
let previousEnd = 0;
for (const cue of story.captionCues) {
  if (
    !Number.isInteger(cue.from) ||
    !Number.isInteger(cue.duration) ||
    cue.from < previousEnd ||
    cue.duration <= 0 ||
    cue.from + cue.duration > nextFrame ||
    typeof cue.text !== "string" ||
    cue.text.trim() === ""
  ) {
    throw new Error(`Invalid launch caption at frame ${cue.from}`);
  }
  previousEnd = cue.from + cue.duration;
}

const timecode = (frames) => {
  const milliseconds = Math.round((frames / story.fps) * 1000);
  return new Date(milliseconds).toISOString().slice(11, 23);
};
const vtt = [
  "WEBVTT",
  "",
  ...story.captionCues.flatMap((cue) => [
    `${timecode(cue.from)} --> ${timecode(cue.from + cue.duration)}`,
    cue.text,
    "",
  ]),
].join("\n");
const transcript = [
  "LidPilot — launch candidate transcript (unpublished)",
  "",
  ...story.captionCues.flatMap((cue) => [
    `${timecode(cue.from)}–${timecode(cue.from + cue.duration)}`,
    cue.text,
    "",
  ]),
].join("\n");

await mkdir(output, { recursive: true });
await writeFile(resolve(output, "lidpilot-launch-captions.vtt"), vtt, "utf8");
await writeFile(
  resolve(output, "lidpilot-launch-transcript.txt"),
  transcript,
  "utf8",
);
console.log(
  `Validated 41-second launch timeline and ${story.captionCues.length} caption cues; wrote sidecars to ${output}`,
);
