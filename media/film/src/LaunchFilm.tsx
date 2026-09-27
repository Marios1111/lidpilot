import React from "react";
import { Audio } from "@remotion/media";
import { AbsoluteFill, Sequence, staticFile } from "remotion";
import story from "../story-launch-candidate.json";
import { LaunchControlScene } from "./launch/LaunchControlScene";
import { LaunchEndScene } from "./launch/LaunchEndScene";
import { LaunchFollowScene } from "./launch/LaunchFollowScene";
import { LaunchHookScene } from "./launch/LaunchHookScene";
import { LaunchRevealScene } from "./launch/LaunchRevealScene";
import { CaptionOverlay } from "./scenes/CaptionOverlay";
import { ProductScene } from "./scenes/ProductScene";

export const LaunchFilm: React.FC<{ burnedCaptions?: boolean }> = ({
  burnedCaptions = false,
}) => (
  <AbsoluteFill style={{ background: "#f4f4f1" }}>
    {story.scenes.map((scene) => (
      <Sequence
        key={scene.id}
        from={scene.from}
        durationInFrames={scene.duration}
        layout="none"
      >
        {renderScene(scene.id)}
      </Sequence>
    ))}
    <Sequence from={story.narration.from} layout="none">
      <Audio src={staticFile(story.narration.src)} />
    </Sequence>
    {burnedCaptions ? <CaptionOverlay cues={story.captionCues} /> : null}
  </AbsoluteFill>
);

const renderScene = (id: string): React.ReactNode => {
  switch (id) {
    case "reading-hook":
      return <LaunchHookScene />;
    case "working-hook":
      return <LaunchHookScene working />;
    case "reveal":
      return <LaunchRevealScene />;
    case "screen":
      return (
        <ProductScene
          eyebrow="KEEP SCREEN ON"
          headline="Stay with the lecture."
          supporting="For lectures, reading, and focused work."
          image="keep-screen-on.png"
          presentation="launch"
        />
      );
    case "running":
      return (
        <ProductScene
          eyebrow="KEEP MAC RUNNING"
          headline="Leave the work running."
          supporting="Builds. Downloads. Your local AI task."
          image="keep-mac-running.png"
          presentation="launch"
        />
      );
    case "follow":
      return <LaunchFollowScene />;
    case "control":
      return <LaunchControlScene />;
    case "end":
      return <LaunchEndScene command={story.homebrewCommand} />;
    default:
      throw new Error(`Unknown launch candidate scene: ${id}`);
  }
};
