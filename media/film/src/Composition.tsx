import { Composition } from "remotion";
import { Film } from "./Film";

export const LandscapeFilm = () => (
  <Composition
    id="LidPilotLandscape"
    component={Film}
    durationInFrames={1020}
    fps={30}
    width={1920}
    height={1080}
  />
);

export const VerticalFilm = () => (
  <Composition
    id="LidPilotVertical"
    component={Film}
    durationInFrames={1020}
    fps={30}
    width={1080}
    height={1920}
  />
);
