import React from "react";
import { useCurrentFrame, useVideoConfig } from "remotion";
import { appear, LaunchSurface, NativeCapture } from "./LaunchSurface";

export const LaunchRevealScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const reveal = appear(frame, 1, 18);
  const cardWidth = vertical ? 590 : 485;
  return (
    <LaunchSurface>
      <div
        style={{
          position: "absolute",
          left: vertical ? 80 : 130,
          right: vertical ? 80 : undefined,
          top: vertical ? 238 : 298,
          width: vertical ? undefined : 850,
          opacity: reveal,
          translate: `0 ${(1 - reveal) * 18}px`,
        }}
      >
        <div
          style={{
            fontSize: vertical ? 84 : 110,
            lineHeight: 1.03,
            letterSpacing: "-0.065em",
            fontWeight: 575,
          }}
        >
          Your Mac.
          <br />
          Your choice.
        </div>
        <div
          style={{
            marginTop: 28,
            fontSize: vertical ? 33 : 36,
            letterSpacing: "-0.025em",
            color: "#627078",
          }}
        >
          Right in your menu bar.
        </div>
        <div
          style={{
            marginTop: vertical ? 27 : 40,
            fontSize: vertical ? 25 : 24,
            color: "#66776e",
            letterSpacing: "0.01em",
          }}
        >
          Free and open source.
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          right: vertical ? undefined : 220,
          left: vertical ? "50%" : undefined,
          top: vertical ? 716 : 209,
          translate: vertical ? "-50% 0" : undefined,
        }}
      >
        <NativeCapture
          src="panel-off.png"
          width={cardWidth}
          height={Math.round((cardWidth * 1014) / 740)}
          alt="LidPilot starts Off, with its three modes and session timer available"
        />
      </div>
    </LaunchSurface>
  );
};
