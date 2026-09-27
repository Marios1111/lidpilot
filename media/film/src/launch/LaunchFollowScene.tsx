import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { IllustratedLaptop } from "../scenes/IllustratedLaptop";
import { appear, LaunchSurface, lidEase, NativeCapture } from "./LaunchSurface";

export const LaunchFollowScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const open = interpolate(frame, [8, 62], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: lidEase,
  });
  const cardWidth = vertical ? 490 : 420;
  return (
    <LaunchSurface>
      <div
        style={{
          position: "absolute",
          left: vertical ? 80 : 140,
          top: vertical ? 199 : 145,
          opacity: appear(frame, 0, 14),
        }}
      >
        <div
          style={{
            fontSize: 19,
            letterSpacing: "0.15em",
            color: "#667987",
            fontWeight: 650,
          }}
        >
          FOLLOW LID
        </div>
        <div
          style={{
            marginTop: 20,
            fontSize: vertical ? 70 : 68,
            lineHeight: 1.04,
            letterSpacing: "-0.06em",
            fontWeight: 575,
          }}
        >
          Open for focus.
          <br />
          Closed for work.
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: vertical ? "50%" : 140,
          bottom: vertical ? 300 : 160,
          width: vertical ? 780 : 960,
          translate: vertical ? "-50% 0" : undefined,
          filter: "drop-shadow(0 32px 32px rgba(35,43,51,.14))",
        }}
      >
        <IllustratedLaptop id="launch-follow" open={open} screen="lecture" />
      </div>
      <div
        style={{
          position: "absolute",
          right: vertical ? undefined : 156,
          left: vertical ? "50%" : undefined,
          top: vertical ? 451 : 236,
          translate: vertical ? "-50% 0" : undefined,
        }}
      >
        <NativeCapture
          src="follow-lid.png"
          width={cardWidth}
          height={Math.round((cardWidth * 1010) / 740)}
          alt="Native Follow Lid panel: screen ready when open, work on when closed"
        />
      </div>
    </LaunchSurface>
  );
};
