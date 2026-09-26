import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { palette } from "../palette";
import { SceneFrame, Wordmark } from "./SceneFrame";

export const OpeningScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const reveal = interpolate(frame, [8, 26], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const rise = interpolate(frame, [8, 28], [20, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame background="#1a2028">
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          padding: vertical ? "120px 80px" : "100px 140px",
          textAlign: "center",
          opacity: reveal,
          transform: `translateY(${rise}px)`,
        }}
      >
        <Img
          src={staticFile("native/icon-light.png")}
          alt="LidPilot app icon"
          style={{
            width: vertical ? 152 : 132,
            height: vertical ? 152 : 132,
            borderRadius: vertical ? 34 : 29,
            boxShadow: "0 18px 55px rgba(0, 0, 0, 0.22)",
          }}
        />
        <div style={{ marginTop: vertical ? 34 : 30 }}>
          <Wordmark light />
        </div>
        <div
          style={{
            marginTop: vertical ? 78 : 62,
            color: "#ffffff",
            fontSize: vertical ? 94 : 112,
            lineHeight: 1.02,
            fontWeight: 620,
            letterSpacing: "-0.07em",
            textWrap: "balance",
          }}
        >
          Your Mac.
          <br />
          <span style={{ color: "#aebacc" }}>On your time.</span>
        </div>
        <div
          style={{
            position: "absolute",
            bottom: vertical ? 120 : 110,
            color: palette.muted,
            fontSize: vertical ? 20 : 18,
            letterSpacing: "0.16em",
            textTransform: "uppercase",
          }}
        >
          LidPilot · Native macOS app
        </div>
      </AbsoluteFill>
    </SceneFrame>
  );
};
