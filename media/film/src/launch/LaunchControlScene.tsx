import React from "react";
import { useCurrentFrame, useVideoConfig } from "remotion";
import { appear, LaunchSurface, NativeCapture } from "./LaunchSurface";

export const LaunchControlScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const vertical = height > width;
  const stopped = frame >= 82;
  const cardWidth = vertical ? 620 : 452;

  return (
    <LaunchSurface>
      <div
        style={{
          position: "absolute",
          top: vertical ? 208 : 164,
          left: 76,
          right: 76,
          textAlign: "center",
          fontSize: vertical ? 62 : 72,
          fontWeight: 560,
          lineHeight: 1.05,
          letterSpacing: "-0.06em",
          opacity: appear(frame),
        }}
      >
        Your time. Your call.
      </div>
      <div
        style={{
          position: "absolute",
          top: vertical ? 400 : 290,
          left: "50%",
          translate: "-50% 0",
        }}
      >
        <NativeCapture
          src={stopped ? "panel-off.png" : "follow-lid.png"}
          alt={
            stopped
              ? "LidPilot is off; normal macOS behavior is restored"
              : "Active Follow Lid session with a one-hour duration and Turn Off control"
          }
          width={cardWidth}
          height={Math.round(cardWidth / (740 / 1014))}
        />
      </div>
    </LaunchSurface>
  );
};
