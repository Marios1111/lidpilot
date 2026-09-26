import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { SceneFrame, Wordmark } from "./SceneFrame";

export const EndScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const opacity = interpolate(frame, [6, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame background="#1a2028">
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          padding: vertical ? "100px 84px" : "90px 150px",
          textAlign: "center",
          opacity,
        }}
      >
        <Img
          src={staticFile("native/icon-light.png")}
          alt="LidPilot app icon"
          style={{
            width: vertical ? 112 : 96,
            height: vertical ? 112 : 96,
            borderRadius: vertical ? 27 : 23,
          }}
        />
        <div style={{ marginTop: 25 }}>
          <Wordmark light />
        </div>
        <div
          style={{
            marginTop: vertical ? 66 : 48,
            maxWidth: vertical ? 880 : 1440,
            color: "#ffffff",
            fontSize: vertical ? 62 : 76,
            lineHeight: 1.1,
            fontWeight: 590,
            letterSpacing: "-0.055em",
            textWrap: "balance",
          }}
        >
          Native. Local.
          <br />
          Free and open source.
        </div>
        <div
          style={{
            marginTop: vertical ? 37 : 28,
            color: "#aebacc",
            fontSize: vertical ? 44 : 49,
            fontWeight: 520,
            letterSpacing: "-0.03em",
          }}
        >
          lidpilot.app
        </div>
      </AbsoluteFill>
    </SceneFrame>
  );
};
