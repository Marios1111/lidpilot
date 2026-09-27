import "./index.css";
import { LaunchCompositions } from "./LaunchComposition";
import {
  LandscapeFilm,
  LandscapeSocialFilm,
  VerticalFilm,
  VerticalSocialFilm,
} from "./Composition";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <LandscapeFilm />
      <LandscapeSocialFilm />
      <VerticalFilm />
      <VerticalSocialFilm />
      <LaunchCompositions />
    </>
  );
};
