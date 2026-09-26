import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { palette } from "../palette";

type SceneFrameProps = {
  children: React.ReactNode;
  background?: string;
};

export const SceneFrame: React.FC<SceneFrameProps> = ({
  children,
  background = palette.porcelain,
}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const rise = interpolate(frame, [0, 16], [12, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background,
        color: palette.graphite,
        opacity,
        transform: `translateY(${rise}px)`,
        overflow: "hidden",
      }}
    >
      {children}
    </AbsoluteFill>
  );
};

export const Wordmark: React.FC<{ light?: boolean; icon?: boolean }> = ({
  light = false,
  icon = false,
}) => {
  const color = light ? "#ffffff" : palette.graphite;
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 14,
        color,
        fontSize: 25,
        fontWeight: 650,
        letterSpacing: "-0.04em",
      }}
    >
      {icon ? (
        <Img
          src={staticFile("native/icon-light.png")}
          alt="LidPilot app icon"
          style={{ width: 44, height: 44, borderRadius: 11 }}
        />
      ) : null}
      <span>LidPilot</span>
    </div>
  );
};

export const Kicker: React.FC<{ children: React.ReactNode; light?: boolean }> = ({
  children,
  light = false,
}) => (
  <div
    style={{
      color: light ? "#aab7c6" : palette.slate,
      fontSize: 19,
      fontWeight: 650,
      letterSpacing: "0.16em",
      textTransform: "uppercase",
    }}
  >
    {children}
  </div>
);
