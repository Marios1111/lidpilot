import React from "react";
import { Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { appear, LaunchSurface } from "./LaunchSurface";

export const LaunchEndScene: React.FC<{ command: string }> = ({ command }) => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const nativeReveal = appear(frame, 0, 18);
  const freeReveal = appear(frame, 52, 16);
  const installReveal = appear(frame, 123, 18);
  const taglineReveal = appear(frame, 309, 18);
  return (
    <LaunchSurface dark header={false}>
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: vertical ? 244 : 127,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          opacity: nativeReveal,
        }}
      >
        <Img
          src={staticFile("native/icon-light.png")}
          alt="LidPilot app icon"
          style={{
            width: vertical ? 116 : 92,
            height: vertical ? 116 : 92,
            borderRadius: vertical ? 28 : 22,
            boxShadow: "0 17px 44px rgba(0,0,0,.2)",
          }}
        />
        <div
          style={{
            marginTop: 20,
            fontSize: vertical ? 27 : 24,
            fontWeight: 600,
            letterSpacing: "-0.035em",
          }}
        >
          LidPilot
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          top: vertical ? 495 : 294,
          left: 70,
          right: 70,
          textAlign: "center",
        }}
      >
        <div
          style={{
            fontSize: vertical ? 30 : 25,
            color: "#bac6cc",
            letterSpacing: "-0.02em",
            opacity: nativeReveal,
          }}
        >
          Native to macOS.
        </div>
        <div
          style={{
            marginTop: vertical ? 35 : 23,
            fontSize: vertical ? 88 : 98,
            lineHeight: 1.03,
            fontWeight: 560,
            letterSpacing: "-0.065em",
            opacity: freeReveal,
          }}
        >
          {vertical ? (
            <>
              Free and
              <br />
              open source.
            </>
          ) : (
            "Free and open source."
          )}
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: vertical ? 80 : 260,
          right: vertical ? 80 : 260,
          top: vertical ? 934 : 541,
          textAlign: "center",
          opacity: installReveal,
          translate: `0 ${(1 - installReveal) * 14}px`,
        }}
      >
        <div
          style={{
            marginBottom: 20,
            fontSize: vertical ? 28 : 24,
            color: "#c1cbd0",
            letterSpacing: "-0.02em",
          }}
        >
          Install with Homebrew
        </div>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: vertical ? 18 : 24,
            padding: vertical ? "32px 22px" : "29px 40px",
            border: "1px solid rgba(214,226,233,.16)",
            borderRadius: 16,
            background: "rgba(12,19,25,.6)",
            boxShadow: "0 16px 48px rgba(0,0,0,.1)",
            fontFamily: "SFMono-Regular, Menlo, monospace",
            fontSize: vertical ? 29 : 35,
            fontWeight: 450,
            letterSpacing: "-0.045em",
            whiteSpace: "nowrap",
          }}
        >
          <span aria-hidden="true" style={{ color: "#789080" }}>
            $
          </span>
          <span>{command}</span>
        </div>
        <div
          style={{
            marginTop: 30,
            fontSize: vertical ? 31 : 30,
            color: "#adbcc5",
            letterSpacing: "-0.025em",
          }}
        >
          Or download at{" "}
          <span style={{ color: "#eef2f3", fontWeight: 550 }}>
            lidpilot.app
          </span>
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 76,
          right: 76,
          top: vertical ? 1417 : 817,
          textAlign: "center",
          fontSize: vertical ? 41 : 36,
          color: "#d8e0e4",
          letterSpacing: "-0.035em",
          opacity: taglineReveal,
        }}
      >
        Your Mac, on your time.
      </div>
    </LaunchSurface>
  );
};
