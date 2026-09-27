import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { palette } from "../palette";
import { IllustratedLaptop } from "./IllustratedLaptop";
import { Kicker, SceneFrame, Wordmark } from "./SceneFrame";
import { TaskStream } from "./TaskStream";

type ProductSceneProps = {
  eyebrow: string;
  headline: string;
  supporting: string;
  image: string;
  presentation?: "launch";
};

const captureDimensions: Record<string, { width: number; height: number }> = {
  "keep-screen-on.png": { width: 740, height: 1020 },
  "keep-mac-running.png": { width: 740, height: 1008 },
};

export const ProductScene: React.FC<ProductSceneProps> = ({
  eyebrow,
  headline,
  supporting,
  image,
  presentation,
}) => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const vertical = height > width;
  const running = image === "keep-mac-running.png";
  const launch = presentation === "launch";
  const captureSize = captureDimensions[image];
  const panelWidth = vertical ? 490 : 420;
  const panelHeight = Math.round(panelWidth / (captureSize.width / captureSize.height));
  const panelReveal = interpolate(frame, launch ? [0, 18] : [10, 38], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const deviceRise = interpolate(frame, launch ? [0, 22] : [0, 58], launch ? [15, 0] : [56, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const deviceScale = interpolate(frame, [0, 74], launch ? [1, 1] : [0.93, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const open = launch && running ? 0 : running
    ? interpolate(frame, [30, 104], [1, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 1;
  const progress = interpolate(frame, [0, 65, 225], [0.58, 0.7, 0.9], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const headlineReveal = interpolate(frame, [0, 24], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame>
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 55% 57%, #ffffff 0%, #f4f4f1 47%, #e7e9e7 100%)",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: vertical ? 76 : 112,
            right: vertical ? 76 : 112,
            top: vertical ? 84 : 66,
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            opacity: headlineReveal,
          }}
        >
          <Wordmark icon />
          <Kicker>Native macOS app</Kicker>
        </div>

        <div
          style={{
            position: "absolute",
            left: vertical ? 76 : 140,
            right: vertical ? 76 : undefined,
            top: vertical ? 178 : 174,
            width: vertical ? undefined : 920,
            opacity: headlineReveal,
            translate: `0 ${interpolate(frame, [0, 24], [24, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            })}px`,
          }}
        >
          <Kicker>{eyebrow}</Kicker>
          <div
            style={{
              marginTop: vertical ? 17 : 20,
              maxWidth: vertical ? 900 : 900,
              color: palette.graphite,
              fontSize: vertical ? 58 : 72,
              lineHeight: 1.04,
              fontWeight: 590,
              letterSpacing: "-0.06em",
              textWrap: "balance",
            }}
          >
            {headline}
          </div>
          <div
            style={{
              marginTop: 14,
              maxWidth: vertical ? 760 : 640,
              color: palette.secondary,
              fontSize: vertical ? 27 : 27,
              lineHeight: 1.28,
              fontWeight: 420,
              letterSpacing: "-0.02em",
              textWrap: "balance",
            }}
          >
            {supporting}
          </div>
        </div>

        <div
          style={{
            position: "absolute",
            width: vertical ? 780 : 960,
            left: vertical ? "50%" : 140,
            bottom: vertical ? 300 : 160,
            translate: `${vertical ? "-50%" : "0"} ${deviceRise}px`,
            scale: deviceScale,
            filter: "drop-shadow(0 42px 38px rgba(35, 43, 51, .17))",
          }}
        >
          <IllustratedLaptop
            id={running ? "running-scene" : "reading-scene"}
            open={open}
            screen={running ? "task" : "lecture"}
            progress={progress}
            dim={0}
          />
        </div>

        {running ? (
          <div
            style={{
              position: "absolute",
              left: vertical ? 295 : 980,
              right: vertical ? 295 : undefined,
              width: vertical ? undefined : 310,
              top: vertical ? 1090 : 700,
              padding: vertical ? "14px 18px" : "20px 22px",
              border: "1px solid rgba(222, 228, 230, .12)",
              borderRadius: 16,
              background: "rgba(27, 37, 44, .91)",
              boxShadow: "0 18px 52px rgba(25, 33, 40, .2)",
              opacity: interpolate(frame, [25, 52], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              }),
            }}
          >
            <TaskStream progress={progress} active={launch || frame > 104} label="LOCAL TASK · BUILD" compact />
          </div>
        ) : null}

        <div
          style={{
            position: "absolute",
            width: panelWidth,
            height: panelHeight,
            right: vertical ? undefined : 156,
            left: vertical ? "50%" : undefined,
            top: vertical ? 410 : 236,
            translate: vertical
              ? `-50% ${interpolate(frame, [0, 34], [52, 0], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                })}px`
              : `${interpolate(frame, [0, 34], [54, 0], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                })}px 0`,
            scale: interpolate(frame, [0, 44], [0.96, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
            opacity: panelReveal,
            borderRadius: 20,
            overflow: "hidden",
            background: "#fff",
            boxShadow: "0 27px 78px rgba(29, 36, 45, .17), 0 3px 12px rgba(29, 36, 45, .07)",
          }}
        >
          <Img
            src={staticFile(`native/${image}`)}
            alt={`LidPilot native ${eyebrow.toLowerCase()} panel`}
            style={{ width: "100%", height: "100%", objectFit: "contain" }}
          />
        </div>
      </AbsoluteFill>
    </SceneFrame>
  );
};
