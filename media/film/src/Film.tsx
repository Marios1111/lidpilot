import React from "react";
import { Audio } from "@remotion/media";
import { AbsoluteFill, Sequence, staticFile } from "remotion";
import rawStory from "../story.json";
import { CaptionCue, CaptionOverlay } from "./scenes/CaptionOverlay";
import { ControlScene } from "./scenes/ControlScene";
import { EndScene } from "./scenes/EndScene";
import { FollowScene } from "./scenes/FollowScene";
import { OpeningScene } from "./scenes/OpeningScene";
import { ProblemScene } from "./scenes/ProblemScene";
import { ProductScene } from "./scenes/ProductScene";
import { RevealScene } from "./scenes/RevealScene";

type SceneTiming = {
  id: string;
  from: number;
  duration: number;
  caption?: string;
  captionCues?: CaptionCue[];
};

type FilmProps = {
  burnedCaptions?: boolean;
};

const timeline = rawStory as SceneTiming[];
const narrationCues = timeline.flatMap((scene) =>
  scene.captionCues ??
    (scene.caption ? [{ from: scene.from, duration: scene.duration, text: scene.caption }] : []),
);

export const Film: React.FC<FilmProps> = ({ burnedCaptions = false }) => (
  <AbsoluteFill>
    {timeline.map((scene) => (
      <Sequence
        key={scene.id}
        from={scene.from}
        durationInFrames={scene.duration}
        layout="none"
      >
        {renderScene(scene.id)}
      </Sequence>
    ))}
    <Sequence from={90} layout="none">
      <Audio src={staticFile("narration-take-1.mp3")} />
    </Sequence>
    {burnedCaptions ? <CaptionOverlay cues={narrationCues} /> : null}
  </AbsoluteFill>
);

const renderScene = (id: string): React.ReactNode => {
  switch (id) {
    case "opening":
      return <OpeningScene />;
    case "problem":
      return <ProblemScene />;
    case "reveal":
      return <RevealScene />;
    case "screen":
      return (
        <ProductScene
          eyebrow="KEEP SCREEN ON"
          headline="Stay with the lecture."
          supporting="For lectures, notes, and reading along."
          image="keep-screen-on.png"
        />
      );
    case "running":
      return (
        <ProductScene
          eyebrow="KEEP MAC RUNNING"
          headline="Leave the work running."
          supporting="For long tasks, with the lid open or closed."
          image="keep-mac-running.png"
        />
      );
    case "follow":
      return <FollowScene />;
    case "timer":
      return <ControlScene />;
    case "end":
      return <EndScene />;
    default:
      throw new Error(`Unknown LidPilot film scene: ${id}`);
  }
};
