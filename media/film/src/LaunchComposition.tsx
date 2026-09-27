import { Composition, Folder } from "remotion";
import story from "../story-launch-candidate.json";
import { LaunchFilm } from "./LaunchFilm";

export const LaunchCompositions = () => (
  <Folder name="Launch-candidate">
    <Composition
      id="LidPilotLaunchLandscape"
      component={LaunchFilm}
      defaultProps={{ burnedCaptions: false }}
      durationInFrames={story.durationInFrames}
      fps={story.fps}
      width={1920}
      height={1080}
    />
    <Composition
      id="LidPilotLaunchLandscapeSocial"
      component={LaunchFilm}
      defaultProps={{ burnedCaptions: true }}
      durationInFrames={story.durationInFrames}
      fps={story.fps}
      width={1920}
      height={1080}
    />
    <Composition
      id="LidPilotLaunchVertical"
      component={LaunchFilm}
      defaultProps={{ burnedCaptions: false }}
      durationInFrames={story.durationInFrames}
      fps={story.fps}
      width={1080}
      height={1920}
    />
    <Composition
      id="LidPilotLaunchVerticalSocial"
      component={LaunchFilm}
      defaultProps={{ burnedCaptions: true }}
      durationInFrames={story.durationInFrames}
      fps={story.fps}
      width={1080}
      height={1920}
    />
  </Folder>
);
