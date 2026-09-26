import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { palette } from "../palette";
import { Kicker, SceneFrame, Wordmark } from "./SceneFrame";

type ProductSceneProps = {
  eyebrow: string;
  headline: string;
  supporting: string;
  image: string;
};

const nativeCaptureDimensions: Record<string, { width: number; height: number }> = {
  "follow-lid.png": { width: 740, height: 1008 },
  "keep-screen-on.png": { width: 740, height: 1020 },
  "keep-mac-running.png": { width: 740, height: 1008 },
  "panel-off.png": { width: 740, height: 1008 },
};

export const ProductScene: React.FC<ProductSceneProps> = ({
  eyebrow,
  headline,
  supporting,
  image,
}) => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();
  const vertical = height > width;
  const captureSize = nativeCaptureDimensions[image];
  const mediaWidth = vertical ? 690 : 615;
  const mediaHeight = Math.round(mediaWidth / (captureSize.width / captureSize.height));
  const mediaOpacity = interpolate(frame, [3, 18], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const mediaX = interpolate(frame, [3, 20], [vertical ? 0 : 24, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <SceneFrame>
      <AbsoluteFill
        style={{
          padding: vertical ? "70px 84px 110px" : "70px 110px 72px",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: vertical ? 84 : 100,
            left: vertical ? 84 : 110,
            right: vertical ? 84 : 110,
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
          }}
        >
          <Wordmark />
          <Kicker>Native macOS app</Kicker>
        </div>

        {vertical ? (
          <>
            <div
              style={{
                position: "absolute",
                top: 126,
                left: 0,
                right: 0,
                height: mediaHeight,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                opacity: mediaOpacity,
                transform: `translateX(${mediaX}px)`,
              }}
            >
              <div
                style={{
                  width: mediaWidth,
                  height: mediaHeight,
                  borderRadius: 22,
                  overflow: "hidden",
                  background: palette.paper,
                  boxShadow: "0 28px 80px rgba(29, 36, 45, 0.14)",
                }}
              >
                <Img
                  src={staticFile(`native/${image}`)}
                  alt="LidPilot macOS menu-bar panel showing a selected session mode"
                  style={{ width: "100%", height: "100%", objectFit: "contain" }}
                />
              </div>
            </div>
            <div
              style={{
                position: "absolute",
                top: 1158,
                left: 84,
                right: 84,
                textAlign: "center",
              }}
            >
              <Kicker>{eyebrow}</Kicker>
              <div
                style={{
                  marginTop: 23,
                  fontSize: 84,
                  lineHeight: 1.08,
                  fontWeight: 630,
                  letterSpacing: "-0.055em",
                  textWrap: "balance",
                }}
              >
                {headline}
              </div>
              <div
                style={{
                  margin: "22px auto 0",
                  maxWidth: 850,
                  color: palette.secondary,
                  fontSize: 44,
                  lineHeight: 1.24,
                  fontWeight: 430,
                  letterSpacing: "-0.025em",
                  textWrap: "balance",
                }}
              >
                {supporting}
              </div>
            </div>
            <div
              style={{
                position: "absolute",
                bottom: 110,
                left: 0,
                right: 0,
                textAlign: "center",
                color: palette.muted,
                fontSize: 19,
                letterSpacing: "0.12em",
                textTransform: "uppercase",
              }}
            >
              LidPilot · Native macOS app
            </div>
          </>
        ) : (
          <>
            <div
              style={{
                position: "absolute",
                top: 0,
                bottom: 0,
                left: 130,
                width: 850,
                display: "flex",
                flexDirection: "column",
                justifyContent: "center",
                paddingTop: 30,
              }}
            >
              <Kicker>{eyebrow}</Kicker>
              <div
                style={{
                  marginTop: 30,
                  maxWidth: 840,
                  fontSize: 92,
                  lineHeight: 1.03,
                  fontWeight: 630,
                  letterSpacing: "-0.06em",
                  textWrap: "balance",
                }}
              >
                {headline}
              </div>
              <div
                style={{
                  marginTop: 30,
                  maxWidth: 740,
                  color: palette.secondary,
                  fontSize: 44,
                  lineHeight: 1.32,
                  fontWeight: 430,
                  letterSpacing: "-0.03em",
                  textWrap: "balance",
                }}
              >
                {supporting}
              </div>
            </div>
            <div
              style={{
                position: "absolute",
                right: 130,
                top: 145,
                height: mediaHeight,
                width: mediaWidth,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                opacity: mediaOpacity,
                transform: `translateX(${mediaX}px)`,
              }}
            >
              <div
                style={{
                  width: "100%",
                  height: "100%",
                  borderRadius: 20,
                  overflow: "hidden",
                  background: palette.paper,
                  boxShadow: "0 26px 72px rgba(29, 36, 45, 0.14)",
                }}
              >
                <Img
                  src={staticFile(`native/${image}`)}
                  alt="LidPilot macOS menu-bar panel showing a selected session mode"
                  style={{ width: "100%", height: "100%", objectFit: "contain" }}
                />
              </div>
            </div>
            <div
              style={{
                position: "absolute",
                bottom: 94,
                left: 130,
                color: palette.muted,
                fontSize: 18,
                letterSpacing: "0.12em",
                textTransform: "uppercase",
              }}
            >
              Native macOS app · lidpilot.app
            </div>
          </>
        )}
      </AbsoluteFill>
    </SceneFrame>
  );
};
