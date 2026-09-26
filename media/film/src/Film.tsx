import React from "react";
import { AbsoluteFill, Sequence } from "remotion";
import rawStory from "../story.json";
import { EndScene } from "./scenes/EndScene";
import { FollowScene } from "./scenes/FollowScene";
import { OpeningScene } from "./scenes/OpeningScene";
import { ProductScene } from "./scenes/ProductScene";

type SceneTiming = {
  id: string;
  from: number;
  duration: number;
};

const timeline = rawStory as SceneTiming[];

export const Film: React.FC = () => (
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
  </AbsoluteFill>
);

const renderScene = (id: string): React.ReactNode => {
  switch (id) {
    case "opening":
      return <OpeningScene />;
    case "screen":
      return (
        <ProductScene
          eyebrow="KEEP SCREEN ON"
          headline="Stay with the lecture."
          supporting="Brightness stays yours."
          image="keep-screen-on.png"
        />
      );
    case "running":
      return (
        <ProductScene
          eyebrow="KEEP MAC RUNNING"
          headline="Leave the work running."
          supporting="Builds. Downloads. Long tasks."
          image="keep-mac-running.png"
        />
      );
    case "follow":
      return <FollowScene />;
    case "timer":
      return (
        <ProductScene
          eyebrow="SESSION TIMER"
          headline="Set your time."
          supporting="30 minutes. A few hours. Until you stop."
          image="keep-screen-on.png"
        />
      );
    case "off":
      return (
        <ProductScene
          eyebrow="ALWAYS STARTS OFF"
          headline="Safety stays awake."
          supporting="You stay in control. Always starts Off."
          image="panel-off.png"
        />
      );
    case "end":
      return <EndScene />;
    default:
      throw new Error(`Unknown LidPilot film scene: ${id}`);
  }
};
