import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { SceneFrame, Wordmark } from "./SceneFrame";

export const EndScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const reveal = interpolate(frame, [0, 36], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const iconScale = interpolate(frame, [0, 48], [0.68, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const nativeReveal = interpolate(frame, [0, 32], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const sourceReveal = interpolate(frame, [90, 118], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const closeReveal = interpolate(frame, [142, 190], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame background="#1a2028">
      <AbsoluteFill
        style={{
          alignItems: "center",
          justifyContent: "center",
          padding: vertical ? "100px 74px" : "84px 130px",
          textAlign: "center",
          background:
            "radial-gradient(ellipse at 50% 42%, #35404a 0%, #222a32 48%, #171d23 100%)",
        }}
      >
        <div style={{ opacity: reveal, scale: iconScale }}>
          <Img
            src={staticFile("native/icon-light.png")}
            alt="LidPilot app icon"
            style={{
              width: vertical ? 112 : 90,
              height: vertical ? 112 : 90,
              borderRadius: vertical ? 27 : 22,
              boxShadow: "0 18px 60px rgba(0, 0, 0, .28)",
            }}
          />
        </div>
        <div style={{ marginTop: vertical ? 28 : 23, opacity: reveal }}>
          <Wordmark light />
        </div>
        <div
          style={{
            marginTop: vertical ? 53 : 43,
            color: "#ffffff",
            fontSize: vertical ? 61 : 70,
            lineHeight: 1.08,
            fontWeight: 570,
            letterSpacing: "-0.06em",
            opacity: nativeReveal,
            translate: `0 ${interpolate(frame, [0, 32], [20, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })}px`,
          }}
        >
          Native. Local.
        </div>
        <div
          style={{
            marginTop: vertical ? 12 : 10,
            color: "#ffffff",
            fontSize: vertical ? 55 : 64,
            lineHeight: 1.08,
            fontWeight: 570,
            letterSpacing: "-0.06em",
            opacity: sourceReveal,
          }}
        >
          Free and open source.
        </div>
        <div
          style={{
            marginTop: vertical ? 30 : 24,
            color: "#b5c0ca",
            fontSize: vertical ? 37 : 40,
            fontWeight: 430,
            letterSpacing: "-0.025em",
            opacity: closeReveal,
          }}
        >
          Your Mac, on your time.
        </div>
        <div
          style={{
            position: "absolute",
            bottom: vertical ? 350 : 170,
            color: "#c2ccd2",
            fontSize: vertical ? 37 : 40,
            fontWeight: 540,
            letterSpacing: "-0.03em",
            opacity: closeReveal,
          }}
        >
          lidpilot.app
        </div>
      </AbsoluteFill>
    </SceneFrame>
  );
};
