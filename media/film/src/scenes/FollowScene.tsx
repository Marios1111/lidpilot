import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { IllustratedLaptop } from "./IllustratedLaptop";
import { SceneFrame, Kicker } from "./SceneFrame";

export const FollowScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const open = interpolate(frame, [0, 46, 60], [0, 1, 0.08], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const panelReveal = interpolate(frame, [4, 22], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const shift = interpolate(frame, [0, 60], [28, -8], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame>
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 50% 53%, #ffffff 0%, #f4f4f1 51%, #e5e8e6 100%)",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: vertical ? 78 : 125,
            top: vertical ? 155 : 105,
            opacity: panelReveal,
          }}
        >
          <Kicker>One connected routine</Kicker>
        </div>
        <div
          style={{
            position: "absolute",
            width: vertical ? 880 : 930,
            left: vertical ? "50%" : 80,
            bottom: vertical ? 390 : 160,
            translate: `${vertical ? "-50%" : "0"} ${shift}px`,
            filter: "drop-shadow(0 34px 34px rgba(35, 43, 51, .16))",
          }}
        >
          <IllustratedLaptop id="follow-transition" open={open} screen="lecture" dim={0} />
        </div>
        <svg
          aria-hidden="true"
          viewBox="0 0 520 100"
          style={{
            position: "absolute",
            width: vertical ? 400 : 480,
            height: 92,
            left: vertical ? "50%" : 900,
            top: vertical ? 1280 : 792,
            translate: vertical ? "-50% 0" : undefined,
            opacity: panelReveal,
            overflow: "visible",
          }}
        >
          <path d="M12 50 H508" stroke="#c5ccd0" strokeWidth="2" />
          <path d="M12 50 H508" stroke="#6f8b9b" strokeWidth="2" strokeDasharray="5 10" opacity="0.8" />
          <circle cx={interpolate(frame, [0, 60], [12, 508], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })} cy="50" r="10" fill="#6f8b9b" />
          <circle cx="12" cy="50" r="17" fill="#f4f4f1" stroke="#9ba8af" strokeWidth="2" />
          <circle cx="508" cy="50" r="17" fill="#f4f4f1" stroke="#9ba8af" strokeWidth="2" />
        </svg>
        <div
          style={{
            position: "absolute",
            width: vertical ? 590 : 390,
            height: vertical ? 805 : 532,
            right: vertical ? undefined : 180,
            left: vertical ? "50%" : undefined,
            top: vertical ? 345 : 188,
            translate: vertical ? "-50% 0" : undefined,
            scale: interpolate(frame, [0, 60], [0.93, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
            opacity: panelReveal,
            borderRadius: 18,
            overflow: "hidden",
            background: "#fff",
            boxShadow: "0 26px 76px rgba(29, 36, 45, .17)",
          }}
        >
          <Img
            src={staticFile("native/follow-lid.png")}
            alt="LidPilot native Follow Lid control panel"
            style={{ width: "100%", height: "100%", objectFit: "contain" }}
          />
        </div>
      </AbsoluteFill>
    </SceneFrame>
  );
};
