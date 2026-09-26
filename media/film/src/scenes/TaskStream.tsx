import React from "react";
import { interpolate, useCurrentFrame } from "remotion";

type TaskStreamProps = {
  progress: number;
  active: boolean;
  label?: string;
  compact?: boolean;
};

export const TaskStream: React.FC<TaskStreamProps> = ({
  progress,
  active,
  label = "LOCAL BUILD",
  compact = false,
}) => {
  const frame = useCurrentFrame();
  const pulse = active
    ? interpolate(frame % 36, [0, 18, 36], [0.45, 1, 0.45])
    : 0.45;
  const percent = Math.round(progress * 100);

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        gap: compact ? 12 : 20,
        width: "100%",
        color: "#e8ecee",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <span
            style={{
              width: compact ? 8 : 10,
              height: compact ? 8 : 10,
              borderRadius: "50%",
              background: active ? "#9bc7b5" : "#89939c",
              opacity: pulse,
            }}
          />
          <span
            style={{
              fontFamily: "Menlo, monospace",
              fontSize: compact ? 13 : 17,
              letterSpacing: "0.12em",
              color: "#d9e0e3",
            }}
          >
            {label}
          </span>
        </div>
        <span
          style={{
            fontFamily: "Menlo, monospace",
            fontSize: compact ? 13 : 17,
            color: "#9ba8af",
          }}
        >
          {String(percent).padStart(2, "0")} %
        </span>
      </div>
      <div
        style={{
          height: compact ? 3 : 4,
          borderRadius: 4,
          background: "rgba(215, 225, 229, 0.2)",
          overflow: "hidden",
        }}
      >
        <div
          style={{
            width: `${percent}%`,
            height: "100%",
            borderRadius: 4,
            background: active ? "#a1c4b7" : "#8b969f",
          }}
        />
      </div>
    </div>
  );
};
