import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { SceneFrame, Wordmark, Kicker } from "./SceneFrame";

export const ControlScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const fadeToOff = interpolate(frame, [76, 102], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const activeOpacity = interpolate(frame, [76, 102], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const cardWidth = vertical ? 620 : 452;
  const cardHeight = Math.round(cardWidth / (740 / 1014));
  const changeScale = interpolate(frame, [0, 90, 180], [0.96, 1, 0.97], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame>
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 50% 54%, #ffffff 0%, #f4f4f1 48%, #e6e9e7 100%)",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: vertical ? 74 : 112,
            right: vertical ? 74 : 112,
            top: vertical ? 90 : 74,
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
          }}
        >
          <Wordmark icon />
          <Kicker>Choose when to stop</Kicker>
        </div>
        <div
          style={{
            position: "absolute",
            left: vertical ? 0 : 0,
            right: vertical ? 0 : 0,
            top: vertical ? 190 : 150,
            textAlign: "center",
            color: "#303943",
            fontSize: vertical ? 54 : 66,
            lineHeight: 1.06,
            fontWeight: 580,
            letterSpacing: "-0.06em",
            opacity: interpolate(frame, [0, 24], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          Start on your terms.
        </div>
        <div
          style={{
            position: "absolute",
            top: vertical ? 390 : 284,
            left: "50%",
            translate: "-50% 0",
            width: cardWidth,
            height: cardHeight,
          }}
        >
          <NativeCard
            src="keep-screen-on.png"
            alt="Active Keep Screen On session with a one-hour timer and Turn Off control"
            width={cardWidth}
            height={cardHeight}
            opacity={activeOpacity}
            scale={changeScale}
          />
          <NativeCard
            src="panel-off.png"
            alt="LidPilot Off state with Start Session control"
            width={cardWidth}
            height={cardHeight}
            opacity={fadeToOff}
            scale={interpolate(frame, [76, 102], [0.96, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })}
          />
        </div>
      </AbsoluteFill>
    </SceneFrame>
  );
};

type NativeCardProps = {
  src: string;
  alt: string;
  width: number;
  height: number;
  opacity: number;
  scale: number;
};

const NativeCard: React.FC<NativeCardProps> = ({ src, alt, width, height, opacity, scale }) => (
  <div
    style={{
      position: "absolute",
      top: 0,
      left: 0,
      width,
      height,
      borderRadius: 18,
      overflow: "hidden",
      background: "#fff",
      boxShadow: "0 24px 74px rgba(29, 36, 45, .16), 0 3px 12px rgba(29, 36, 45, .06)",
      opacity,
      scale,
    }}
  >
    <Img
      src={staticFile(`native/${src}`)}
      alt={alt}
      style={{ width: "100%", height: "100%", objectFit: "contain" }}
    />
  </div>
);
