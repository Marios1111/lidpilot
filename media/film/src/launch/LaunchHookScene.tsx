import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { IllustratedLaptop } from "../scenes/IllustratedLaptop";
import { TaskStream } from "../scenes/TaskStream";
import { appear, LaunchSurface, lidEase } from "./LaunchSurface";

export const LaunchHookScene: React.FC<{ working?: boolean }> = ({
  working = false,
}) => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  const vertical = height > width;
  const title = appear(frame, 1, 20);
  const open = working
    ? interpolate(frame, [40, 94], [1, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
        easing: lidEase,
      })
    : 1;
  const progress = interpolate(frame, [0, 113], [0.43, 0.67], {
    extrapolateRight: "clamp",
  });
  return (
    <LaunchSurface dark={working}>
      <div
        style={{
          position: "absolute",
          left: vertical ? 80 : 130,
          right: vertical ? 80 : undefined,
          top: vertical ? 244 : 242,
          width: vertical ? undefined : 690,
          opacity: title,
          translate: `0 ${(1 - title) * 16}px`,
        }}
      >
        <div
          style={{
            fontSize: vertical ? 82 : 102,
            lineHeight: 1.02,
            fontWeight: 575,
            letterSpacing: "-0.065em",
            textWrap: "balance",
          }}
        >
          {working ? (
            <>
              Let the work
              <br />
              carry on.
            </>
          ) : (
            <>
              Keep the lecture
              <br />
              in view.
            </>
          )}
        </div>
        {working ? (
          <div
            style={{
              marginTop: 29,
              fontSize: vertical ? 31 : 32,
              lineHeight: 1.3,
              letterSpacing: "-0.025em",
              color: "#bbc8ce",
            }}
          >
            Even with the lid closed.
          </div>
        ) : null}
      </div>

      <div
        style={{
          position: "absolute",
          width: vertical ? 1080 : 1160,
          left: vertical ? "50%" : 755,
          bottom: vertical ? 385 : 190,
          translate: vertical ? "-50% 0" : undefined,
          filter: working
            ? "drop-shadow(0 32px 32px rgba(0,0,0,.22))"
            : "drop-shadow(0 32px 32px rgba(36,46,52,.15))",
        }}
      >
        <IllustratedLaptop
          id={working ? "launch-work-hook" : "launch-read-hook"}
          open={open}
          screen={working ? "task" : "lecture"}
          progress={progress}
        />
      </div>

      {working ? (
        <div
          style={{
            position: "absolute",
            left: vertical ? 205 : 136,
            right: vertical ? 205 : undefined,
            width: vertical ? undefined : 530,
            top: vertical ? 690 : 616,
            padding: "24px 28px",
            borderRadius: 16,
            border: "1px solid rgba(220,231,234,.13)",
            background: "rgba(15,23,29,.4)",
            opacity: appear(frame, 14, 20),
          }}
        >
          <TaskStream progress={progress} active label="LOCAL BUILD" compact />
        </div>
      ) : null}
    </LaunchSurface>
  );
};
