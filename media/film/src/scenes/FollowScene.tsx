import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { palette } from "../palette";
import { ProductScene } from "./ProductScene";

export const FollowScene: React.FC = () => {
  const { height, width } = useVideoConfig();
  const frame = useCurrentFrame();
  const vertical = height > width;
  const reveal = interpolate(frame, [18, 34], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill>
      <ProductScene
        eyebrow="FOLLOW LID"
        headline="Follow Lid connects both."
        supporting="Open for focus. Closed for work."
        image="follow-lid.png"
      />
      <div
        style={{
          position: "absolute",
          ...(vertical
            ? { top: 1602, left: 160, right: 160, height: 135 }
            : { left: 142, bottom: 125, width: 760, height: 115 }),
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          gap: vertical ? 38 : 58,
          opacity: reveal,
          color: palette.secondary,
          fontSize: vertical ? 21 : 18,
          letterSpacing: "0.11em",
          textTransform: "uppercase",
        }}
      >
        <LidState closed={false} label="Open" />
        <div
          style={{
            width: vertical ? 76 : 100,
            height: 2,
            background: palette.line,
          }}
        />
        <LidState closed label="Closed" />
      </div>
    </AbsoluteFill>
  );
};

const LidState: React.FC<{ closed: boolean; label: string }> = ({ closed, label }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
    <svg width="54" height="42" viewBox="0 0 54 42" fill="none" aria-hidden="true">
      {closed ? (
        <>
          <rect x="7" y="8" width="40" height="25" rx="2" stroke={palette.slate} strokeWidth="2.5" />
          <path d="M4 36h46" stroke={palette.slate} strokeWidth="2.5" strokeLinecap="round" />
        </>
      ) : (
        <>
          <path d="M8 32h37" stroke={palette.slate} strokeWidth="2.5" strokeLinecap="round" />
          <path d="M13 30V8h28v22" stroke={palette.slate} strokeWidth="2.5" strokeLinejoin="round" />
        </>
      )}
    </svg>
    <span>{label}</span>
  </div>
);
