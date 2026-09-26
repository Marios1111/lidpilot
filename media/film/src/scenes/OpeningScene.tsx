import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { SceneFrame } from "./SceneFrame";
import { IllustratedLaptop } from "./IllustratedLaptop";

export const OpeningScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const dim = interpolate(frame, [42, 156], [0, 0.55], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const drift = interpolate(frame, [0, 180], [34, -18], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const reveal = interpolate(frame, [8, 38], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame background="#e6e9e7">
      <AbsoluteFill>
        <div
          style={{
            position: "absolute",
            inset: 0,
            background:
              "radial-gradient(ellipse at 54% 50%, rgba(255,255,255,.9) 0%, rgba(255,255,255,0) 58%), linear-gradient(142deg, #eef0ed 0%, #dce1e2 100%)",
          }}
        />
        <div
          style={{
            position: "absolute",
            top: vertical ? 255 : 154,
            left: vertical ? 78 : 142,
            display: "flex",
            alignItems: "center",
            gap: 14,
            color: "#69747d",
            opacity: reveal,
            fontSize: vertical ? 19 : 17,
            fontWeight: 620,
            letterSpacing: "0.17em",
            textTransform: "uppercase",
          }}
        >
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: "50%",
              background: "#8297a4",
              boxShadow: "0 0 0 7px rgba(130, 151, 164, .12)",
            }}
          />
          Lecture · Week 04
        </div>
        <div
          style={{
            position: "absolute",
            width: vertical ? 950 : 1160,
            left: "50%",
            bottom: vertical ? 485 : 150,
            translate: `-50% ${drift}px`,
            scale: interpolate(frame, [0, 180], [0.96, 1.015], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
            filter: "drop-shadow(0 44px 42px rgba(39, 50, 57, .18))",
          }}
        >
          <IllustratedLaptop id="lecture-open" open={1} screen="lecture" dim={dim} />
        </div>
        <div
          style={{
            position: "absolute",
            right: vertical ? 83 : 150,
            top: vertical ? 375 : 165,
            width: vertical ? 86 : 112,
            height: vertical ? 4 : 3,
            borderRadius: 4,
            background: "rgba(105, 119, 128, .15)",
            overflow: "hidden",
            opacity: reveal,
          }}
        >
          <div
            style={{
              width: `${interpolate(frame, [0, 180], [22, 100], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              })}%`,
              height: "100%",
              background: "#879aa5",
              opacity: 0.75,
            }}
          />
        </div>
      </AbsoluteFill>
    </SceneFrame>
  );
};
