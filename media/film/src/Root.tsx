import "./index.css";
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
    </>
  );
};
