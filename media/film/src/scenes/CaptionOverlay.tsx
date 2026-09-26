import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";

export type CaptionCue = {
  from: number;
  duration: number;
  text: string;
};

type CaptionOverlayProps = {
  cues: CaptionCue[];
};

export const CaptionOverlay: React.FC<CaptionOverlayProps> = ({ cues }) => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const cue = cues.find(({ from, duration }) => frame >= from && frame < from + duration);

  if (!cue) return null;

  const fadeOutAt = cue.from + cue.duration - 8;
  const opacity = interpolate(
    frame,
    [cue.from, cue.from + 8, fadeOutAt, cue.from + cue.duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  return (
    <AbsoluteFill
      style={{
        zIndex: 20,
        justifyContent: "flex-end",
        alignItems: "center",
        padding: vertical ? "0 72px 160px" : "0 112px 90px",
        boxSizing: "border-box",
        pointerEvents: "none",
      }}
    >
      <div
        style={{
          maxWidth: vertical ? 840 : 1560,
          width: "fit-content",
          padding: vertical ? "18px 26px" : "14px 24px",
          border: "1px solid rgba(255, 255, 255, .16)",
          borderRadius: 16,
          background: "rgba(22, 29, 36, .88)",
          boxShadow: "0 10px 28px rgba(16, 22, 28, .2)",
          color: "#ffffff",
          fontSize: vertical ? 40 : 34,
          lineHeight: 1.2,
          fontWeight: 540,
          letterSpacing: "-0.02em",
          textAlign: "center",
          textWrap: "balance",
          opacity,
        }}
      >
        {cue.text}
      </div>
    </AbsoluteFill>
  );
};
