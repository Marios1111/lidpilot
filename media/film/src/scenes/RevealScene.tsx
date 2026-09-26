import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { SceneFrame, Wordmark } from "./SceneFrame";

export const RevealScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const scale = interpolate(frame, [0, 28], [0.88, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame>
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 60% 50%, #ffffff 0%, #f4f4f1 51%, #e7e9e7 100%)",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: vertical ? 0 : 140,
            right: vertical ? 0 : undefined,
            top: vertical ? 300 : 0,
            bottom: vertical ? undefined : 0,
            width: vertical ? undefined : 620,
            display: "flex",
            alignItems: vertical ? "center" : "flex-start",
            justifyContent: "center",
            flexDirection: "column",
            gap: vertical ? 26 : 34,
            textAlign: vertical ? "center" : "left",
            opacity: interpolate(frame, [0, 22], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          <Wordmark icon />
          <div
            style={{
              color: "#303944",
              fontSize: vertical ? 66 : 82,
              lineHeight: 1.04,
              fontWeight: 580,
              letterSpacing: "-0.065em",
            }}
          >
            A clearer way
            <br />
            to stay on task.
          </div>
        </div>
        <div
          style={{
            position: "absolute",
            width: vertical ? 700 : 480,
            height: vertical ? 955 : 655,
            right: vertical ? undefined : 175,
            left: vertical ? "50%" : undefined,
            top: vertical ? 665 : 210,
            translate: vertical ? "-50% 0" : undefined,
            scale,
            borderRadius: 22,
            overflow: "hidden",
            background: "#fff",
            boxShadow: "0 34px 100px rgba(35, 43, 51, .19), 0 4px 16px rgba(35, 43, 51, .08)",
          }}
        >
          <Img
            src={staticFile("native/follow-lid.png")}
            alt="LidPilot's native Follow Lid control panel"
            style={{ width: "100%", height: "100%", objectFit: "contain" }}
          />
        </div>
      </AbsoluteFill>
    </SceneFrame>
  );
};
