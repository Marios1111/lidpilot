import { Composition } from "remotion";
import { Film } from "./Film";

export const LandscapeFilm = () => (
  <Composition
    id="LidPilotLandscape"
    component={Film}
    defaultProps={{ burnedCaptions: false }}
    durationInFrames={1260}
    fps={30}
    width={1920}
    height={1080}
  />
);

export const LandscapeSocialFilm = () => (
  <Composition
    id="LidPilotLandscapeSocial"
    component={Film}
    defaultProps={{ burnedCaptions: true }}
    durationInFrames={1260}
    fps={30}
    width={1920}
    height={1080}
  />
);

export const VerticalFilm = () => (
  <Composition
    id="LidPilotVertical"
    component={Film}
    defaultProps={{ burnedCaptions: false }}
    durationInFrames={1260}
    fps={30}
    width={1080}
    height={1920}
  />
);

export const VerticalSocialFilm = () => (
  <Composition
    id="LidPilotVerticalSocial"
    component={Film}
    defaultProps={{ burnedCaptions: true }}
    durationInFrames={1260}
    fps={30}
    width={1080}
    height={1920}
  />
);
