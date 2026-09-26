import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { IllustratedLaptop } from "./IllustratedLaptop";
import { SceneFrame } from "./SceneFrame";
import { TaskStream } from "./TaskStream";

export const ProblemScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const open = interpolate(frame, [20, 118], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const progress = interpolate(frame, [0, 118, 150], [0.4, 0.62, 0.62], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const camera = interpolate(frame, [0, 118, 150], [0.96, 1.02, 1.02], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame background="#202831">
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 52% 54%, #3b4650 0%, #252e37 52%, #1b2229 100%)",
        }}
      >
        <div
          style={{
            position: "absolute",
            width: vertical ? 930 : 1060,
            left: vertical ? "50%" : "34%",
            top: vertical ? 390 : 205,
            translate: vertical ? "-50% 0" : "-50% 0",
            scale: camera,
            filter: "drop-shadow(0 44px 38px rgba(0, 0, 0, .25))",
          }}
        >
          <IllustratedLaptop id="build-pause" open={open} screen="task" progress={progress} dim={0.05} />
        </div>
        <div
          style={{
            position: "absolute",
            ...(vertical
              ? { left: 108, right: 108, top: 1120 }
              : { right: 132, top: 470, width: 570 }),
            opacity: interpolate(frame, [15, 42], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
            padding: vertical ? "25px 29px" : "29px 34px",
            border: "1px solid rgba(229, 236, 239, .11)",
            borderRadius: 20,
            background: "rgba(14, 20, 26, .36)",
            boxShadow: "0 22px 70px rgba(0, 0, 0, .12)",
            backdropFilter: "blur(8px)",
          }}
        >
          <TaskStream progress={progress} active={frame < 118} label="LOCAL BUILD" />
        </div>
        <svg
          aria-hidden="true"
          viewBox="0 0 1000 500"
          style={{
            position: "absolute",
            width: vertical ? 570 : 780,
            height: vertical ? 330 : 390,
            left: vertical ? 258 : 690,
            top: vertical ? 925 : 360,
            opacity: 0.27,
          }}
        >
          <path d="M0 250 C250 250 360 250 470 250 S720 250 1000 250" fill="none" stroke="#a6b7c0" strokeWidth="2" strokeDasharray="5 12" />
          <circle
            cx={interpolate(frame, [0, 118, 150], [60, 610, 610], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })}
            cy="250"
            r="8"
            fill={frame < 118 ? "#a9c8b8" : "#8e9aa2"}
          />
        </svg>
        <div
          style={{
            position: "absolute",
            bottom: vertical ? 320 : 190,
            left: vertical ? 0 : 140,
            right: vertical ? 0 : undefined,
            width: vertical ? undefined : 560,
            textAlign: vertical ? "center" : "left",
            color: "rgba(236, 241, 243, .86)",
            fontSize: vertical ? 19 : 18,
            letterSpacing: "0.14em",
            textTransform: "uppercase",
            opacity: interpolate(frame, [18, 44, 125, 150], [0, 1, 1, 0.45], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          The work cannot wait. The lid can.
        </div>
      </AbsoluteFill>
    </SceneFrame>
  );
};
