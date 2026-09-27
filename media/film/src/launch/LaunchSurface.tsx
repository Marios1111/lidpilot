import React from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Wordmark } from "../scenes/SceneFrame";

export const launchEase = Easing.bezier(0.22, 1, 0.36, 1);
export const lidEase = Easing.bezier(0.42, 0, 0.22, 1);

export const appear = (frame: number, from = 0, duration = 18) =>
  interpolate(frame, [from, from + duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: launchEase,
  });

export const LaunchSurface: React.FC<{
  children: React.ReactNode;
  dark?: boolean;
  header?: boolean;
}> = ({ children, dark = false, header = true }) => {
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  return (
    <AbsoluteFill
      style={{
        overflow: "hidden",
        background: dark
          ? "radial-gradient(ellipse at 55% 50%, #35414b 0%, #232d35 53%, #1a2229 100%)"
          : "radial-gradient(ellipse at 56% 52%, #ffffff 0%, #f4f4f1 55%, #e9ece9 100%)",
        color: dark ? "#f5f6f4" : "#263038",
      }}
    >
      {header ? (
        <div
          style={{
            position: "absolute",
            top: vertical ? 86 : 74,
            left: vertical ? 80 : 120,
            zIndex: 2,
          }}
        >
          <Wordmark icon light={dark} />
        </div>
      ) : null}
      {children}
    </AbsoluteFill>
  );
};

export const NativeCapture: React.FC<{
  src: string;
  width: number;
  height: number;
  alt: string;
  reveal?: boolean;
}> = ({ src, width, height, alt, reveal = true }) => {
  const frame = useCurrentFrame();
  const opacity = reveal ? appear(frame, 3, 19) : 1;
  return (
    <div
      style={{
        width,
        height,
        overflow: "hidden",
        borderRadius: 20,
        background: "#fff",
        opacity,
        translate: `0 ${(1 - opacity) * 22}px`,
        boxShadow:
          "0 25px 72px rgba(31, 43, 51, .15), 0 2px 8px rgba(31, 43, 51, .06)",
      }}
    >
      <Img
        src={staticFile(`native/${src}`)}
        alt={alt}
        style={{ width: "100%", height: "100%", objectFit: "contain" }}
      />
    </div>
  );
};
