import React from "react";

type Point = readonly [number, number];
type Vector = readonly [number, number, number];
type Plane = (x: number, y: number) => Vector;

type IllustratedLaptopProps = {
  id: string;
  open: number;
  screen: "lecture" | "task";
  dim?: number;
  progress?: number;
};

// Dimensions are shared by the deck and lid. Only the lid's angle changes.
// World space: x = left/right, y = hinge/front edge, z = height above the desk.
const WIDTH = 760;
const DEPTH = 525;
const DECK_Z = 14;
const HINGE_Z = 17.5;
const LID_THICKNESS = 6.5;
const YAW = (-15 * Math.PI) / 180;
const ELEVATION = (25 * Math.PI) / 180;
const CAMERA: Vector = [
  Math.sin(YAW) * Math.cos(ELEVATION),
  Math.cos(YAW) * Math.cos(ELEVATION),
  Math.sin(ELEVATION),
];

const project = ([x, y, z]: Vector): Point => {
  const relative: Vector = [x, y - 245, z - 140];
  const depth = relative.reduce((sum, value, i) => sum + value * CAMERA[i], 0);
  const perspective = 2320 / (3100 - depth);
  return [
    550 + perspective * (relative[0] * Math.cos(YAW) - relative[1] * Math.sin(YAW)),
    445 -
      perspective *
        (-relative[0] * Math.sin(YAW) * Math.sin(ELEVATION) -
          relative[1] * Math.cos(YAW) * Math.sin(ELEVATION) +
          relative[2] * Math.cos(ELEVATION)),
  ];
};

const path = (points: readonly Vector[], close = true) =>
  points
    .map((point, index) => {
      const [x, y] = project(point);
      return `${index === 0 ? "M" : "L"}${x.toFixed(3)} ${y.toFixed(3)}`;
    })
    .join(" ") + (close ? " Z" : "");

const roundedRect = (x: number, y: number, width: number, height: number, radius: number): Point[] => {
  const corners = [
    [x + width - radius, y + radius, -90],
    [x + width - radius, y + height - radius, 0],
    [x + radius, y + height - radius, 90],
    [x + radius, y + radius, 180],
  ];
  return corners.flatMap(([cx, cy, start]) =>
    Array.from({ length: 9 }, (_, step) => {
      const angle = ((start + (step * 90) / 8) * Math.PI) / 180;
      return [cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius] as Point;
    }),
  );
};

const rectPath = (
  plane: Plane,
  x: number,
  y: number,
  width: number,
  height: number,
  radius = 0,
) => path(roundedRect(x, y, width, height, radius).map(([u, v]) => plane(u, v)));

const PlaneRect: React.FC<{
  plane: Plane;
  x: number;
  y: number;
  width: number;
  height: number;
  radius?: number;
  fill: string;
  stroke?: string;
  strokeWidth?: number;
  opacity?: number;
}> = ({ plane, x, y, width, height, radius = 0, ...style }) => (
  <path d={rectPath(plane, x, y, width, height, radius)} {...style} />
);

// A local tangent keeps type attached to its physical face, including during
// foreshortening. All larger geometry uses the exact perspective projection.
const PlaneText: React.FC<{
  plane: Plane;
  x: number;
  y: number;
  children: React.ReactNode;
  size?: number;
  fill?: string;
  weight?: number;
  anchor?: "start" | "middle" | "end";
  mono?: boolean;
}> = ({ plane, x, y, children, size = 12, fill = "#a9b1b8", weight = 450, anchor = "start", mono = false }) => {
  const origin = project(plane(x, y));
  const right = project(plane(x + 1, y));
  const down = project(plane(x, y + 1));
  return (
    <text
      transform={`matrix(${right[0] - origin[0]} ${right[1] - origin[1]} ${down[0] - origin[0]} ${down[1] - origin[1]} ${origin[0]} ${origin[1]})`}
      fontFamily={mono ? "SFMono-Regular, Menlo, monospace" : "-apple-system, BlinkMacSystemFont, sans-serif"}
      fontSize={size}
      fontWeight={weight}
      fill={fill}
      textAnchor={anchor}
    >
      {children}
    </text>
  );
};

const PlaneLine: React.FC<{
  plane: Plane;
  points: Point[];
  stroke: string;
  width?: number;
  opacity?: number;
}> = ({ plane, points, stroke, width = 1, opacity = 1 }) => (
  <path
    d={path(points.map(([x, y]) => plane(x, y)), false)}
    fill="none"
    stroke={stroke}
    strokeWidth={width}
    strokeLinecap="round"
    strokeLinejoin="round"
    opacity={opacity}
  />
);

type Key = { label: string; units: number };
const keyRow = (labels: string[], first = 1, last = 1): Key[] =>
  labels.map((label, i) => ({ label, units: i === 0 ? first : i === labels.length - 1 ? last : 1 }));

const KEY_ROWS: Key[][] = [
  keyRow(["esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "◯"], 1.5, 1.5),
  keyRow(["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "−", "=", "delete"], 1, 2),
  keyRow(["tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"], 1.5, 1.5),
  keyRow(["caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "’", "return"], 1.8, 2.2),
  keyRow(["shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "shift"], 2.3, 2.7),
  [
    { label: "fn", units: 1 },
    { label: "⌃", units: 1 },
    { label: "⌥", units: 1 },
    { label: "⌘", units: 1.35 },
    { label: "", units: 5.3 },
    { label: "⌘", units: 1.35 },
    { label: "⌥", units: 1 },
    { label: "‹", units: 1 },
    { label: "↕", units: 1 },
    { label: "›", units: 1 },
  ],
];

const Keyboard: React.FC<{ id: string }> = ({ id }) => {
  const deck: Plane = (x, y) => [x, y, DECK_Z + 0.3];
  const keyTop: Plane = (x, y) => [x, y, DECK_Z + 1.6];
  return (
    <>
      <PlaneRect plane={deck} x={-307} y={55} width={614} height={255} radius={11} fill="#7e8488" opacity={0.65} />
      <PlaneRect plane={deck} x={-304} y={58} width={608} height={249} radius={9} fill="#22272c" />
      {KEY_ROWS.flatMap((keys, row) => {
        let cursor = -300;
        const y = row === 0 ? 64 : 93 + (row - 1) * 42;
        const height = row === 0 ? 23 : 34;
        return keys.map(({ label, units }, index) => {
          const x = cursor + 3;
          const width = units * 40 - 6;
          cursor += units * 40;
          return (
            <g key={`${row}-${index}`}>
              <PlaneRect plane={deck} x={x} y={y + 1.6} width={width} height={height} radius={4.5} fill="#101417" />
              <PlaneRect plane={keyTop} x={x} y={y} width={width} height={height - 1} radius={4.5} fill={`url(#${id}-key)`} stroke="#62686c" strokeWidth={0.35} />
              {label ? (
                <PlaneText plane={keyTop} x={x + width / 2} y={y + height / 2 + 2.4} size={row === 0 || label.length > 2 ? 7 : 9} fill="#d0d3d4" anchor="middle">
                  {label}
                </PlaneText>
              ) : null}
            </g>
          );
        });
      })}
      {[-335, 335].map((x) => (
        <g key={x} opacity={0.43}>
          {Array.from({ length: 35 }, (_, row) =>
            [-4, 0, 4].map((offset) => (
              <PlaneRect key={`${row}-${offset}`} plane={deck} x={x + offset} y={74 + row * 6.1} width={1.3} height={1.3} radius={0.65} fill="#687074" />
            )),
          )}
        </g>
      ))}
      <PlaneRect plane={deck} x={-156} y={339} width={312} height={146} radius={10} fill="#acb3b7" />
      <PlaneRect plane={deck} x={-154.8} y={340.3} width={309.6} height={143.4} radius={9} fill={`url(#${id}-trackpad)`} stroke="#f4f5f5" strokeWidth={0.35} />
    </>
  );
};

const TaskScreen: React.FC<{ plane: Plane; progress: number }> = ({ plane, progress }) => (
  <>
    <PlaneRect plane={plane} x={0} y={0} width={720} height={465} radius={7} fill="#182128" />
    <PlaneRect plane={plane} x={0} y={0} width={720} height={31} fill="#28323a" />
    {["#bb6c65", "#b79b60", "#77a18b"].map((fill, i) => (
      <PlaneRect key={fill} plane={plane} x={14 + i * 15} y={12} width={6} height={6} radius={3} fill={fill} />
    ))}
    <PlaneText plane={plane} x={360} y={21} size={11} anchor="middle" fill="#bac2c7">Workspace</PlaneText>
    <PlaneRect plane={plane} x={0} y={31} width={138} height={434} fill="#1e282f" />
    <PlaneText plane={plane} x={17} y={59} size={10} fill="#8a99a3" weight={650}>PROJECT</PlaneText>
    {["⌄  src", "   components", "   styles", "   index.tsx", "   package.json"].map((label, i) => (
      <PlaneText key={label} plane={plane} x={18} y={88 + i * 24} size={11} fill={i === 3 ? "#d4dcde" : "#94a3ad"}>{label}</PlaneText>
    ))}
    <PlaneRect plane={plane} x={139} y={31} width={581} height={32} fill="#202c34" />
    <PlaneText plane={plane} x={156} y={51} size={11} fill="#c1cbd1">index.tsx</PlaneText>
    {[
      ["import", " { App } from './App';"],
      ["import", " './styles.css';"],
      ["", ""],
      ["const", " root = createRoot(container);"],
      ["", ""],
      ["root", ".render("],
      ["", "  <App />"],
      ["", ");"],
    ].map(([accent, code], i) => (
      <g key={i}>
        <PlaneText plane={plane} x={163} y={93 + i * 22} size={12} fill="#536975" anchor="end" mono>{i + 1}</PlaneText>
        <PlaneText plane={plane} x={181} y={93 + i * 22} size={12} fill="#b1c5cd" mono>
          <tspan fill="#98afa0">{accent}</tspan>{code}
        </PlaneText>
      </g>
    ))}
    <PlaneLine plane={plane} points={[[139, 301], [720, 301]]} stroke="#3b4951" width={0.8} />
    <PlaneText plane={plane} x={159} y={326} size={10} fill="#adbcc4" weight={600}>TERMINAL</PlaneText>
    <PlaneText plane={plane} x={159} y={354} size={12} fill="#b4c9bd" mono>❯ pnpm build</PlaneText>
    <PlaneText plane={plane} x={159} y={381} size={11} fill="#98a8b1" mono>Building production bundle…</PlaneText>
    <PlaneRect plane={plane} x={160} y={407} width={489} height={3} radius={1.5} fill="#394750" />
    <PlaneRect plane={plane} x={160} y={407} width={489 * Math.max(0.01, Math.min(1, progress))} height={3} radius={1.5} fill="#91b9a5" />
    <PlaneText plane={plane} x={650} y={436} size={10} fill="#91a4ae" anchor="end" mono>{Math.round(progress * 100)}%</PlaneText>
  </>
);

const LectureScreen: React.FC<{ plane: Plane }> = ({ plane }) => (
  <>
    <PlaneRect plane={plane} x={0} y={0} width={720} height={465} radius={7} fill="#ecede8" />
    <PlaneRect plane={plane} x={0} y={0} width={720} height={34} fill="#e0e4e0" />
    {["#b4867d", "#b6a37b", "#8da38c"].map((fill, i) => (
      <PlaneRect key={fill} plane={plane} x={14 + i * 15} y={13} width={6} height={6} radius={3} fill={fill} />
    ))}
    <PlaneText plane={plane} x={360} y={23} size={11} fill="#5c696c" anchor="middle">Week 04 · Systems and structure</PlaneText>
    <PlaneRect plane={plane} x={0} y={34} width={95} height={431} fill="#dce1db" />
    {[0, 1, 2, 3].map((index) => (
      <g key={index}>
        <PlaneRect plane={plane} x={15} y={56 + index * 80} width={65} height={48} radius={3} fill={index === 1 ? "#f7f7f2" : "#ecede6"} stroke={index === 1 ? "#8da39b" : "#cad2ca"} strokeWidth={index === 1 ? 1.4 : 0.6} />
        <PlaneRect plane={plane} x={23} y={69 + index * 80} width={36} height={2} radius={1} fill="#adb8b0" />
        <PlaneRect plane={plane} x={23} y={77 + index * 80} width={47} height={1.5} radius={0.75} fill="#c1c9c0" />
        <PlaneRect plane={plane} x={23} y={85 + index * 80} width={40} height={1.5} radius={0.75} fill="#c1c9c0" />
      </g>
    ))}
    <PlaneRect plane={plane} x={118} y={58} width={577} height={342} radius={3} fill="#f8f8f2" />
    <PlaneText plane={plane} x={155} y={96} size={11} weight={600} fill="#728279">04 / LECTURE NOTES</PlaneText>
    <PlaneText plane={plane} x={152} y={148} size={36} weight={540} fill="#293c35">Systems in balance.</PlaneText>
    <PlaneText plane={plane} x={155} y={181} size={14} fill="#758079">How individual parts work together.</PlaneText>
    <PlaneLine plane={plane} points={[[155, 208], [656, 208]]} stroke="#d2d9ce" width={0.7} />
    {[
      [155, "01", "Observe", "See the whole system."],
      [324, "02", "Connect", "Follow the relationships."],
      [493, "03", "Refine", "Make room for change."],
    ].map(([x, number, title, subtitle]) => (
      <g key={number}>
        <PlaneRect plane={plane} x={Number(x)} y={237} width={138} height={70} radius={2} fill="#e5eae0" />
        <PlaneText plane={plane} x={Number(x) + 12} y={265} size={21} weight={450} fill="#869a89">{number}</PlaneText>
        <PlaneText plane={plane} x={Number(x)} y={334} size={15} weight={550} fill="#3b5044">{title}</PlaneText>
        <PlaneText plane={plane} x={Number(x)} y={356} size={10} fill="#7c887c">{subtitle}</PlaneText>
      </g>
    ))}
    <PlaneRect plane={plane} x={118} y={418} width={577} height={26} radius={4} fill="#dce2d8" />
    <PlaneText plane={plane} x={134} y={436} size={12} fill="#697a6c">Ⅱ</PlaneText>
    <PlaneRect plane={plane} x={161} y={430} width={448} height={2.5} radius={1.25} fill="#bdc9bb" />
    <PlaneRect plane={plane} x={161} y={430} width={162} height={2.5} radius={1.25} fill="#7f9582" />
    <PlaneText plane={plane} x={675} y={435} size={10} fill="#7c8a7c" anchor="end">18:42</PlaneText>
  </>
);

export const IllustratedLaptop: React.FC<IllustratedLaptopProps> = ({
  id,
  open,
  screen,
  dim = 0,
  progress = 0.48,
}) => {
  const angle = (Math.max(0, Math.min(1, open)) * 104 * Math.PI) / 180;
  const sin = Math.sin(angle);
  const cos = Math.cos(angle);
  const deck: Plane = (x, y) => [x, y, DECK_Z];
  const lid = (x: number, distance: number, normal = 0): Vector => [
    x,
    distance * cos + normal * sin,
    HINGE_Z + distance * sin - normal * cos,
  ];
  const inside: Plane = (x, y) => lid(x, y);
  const outside: Plane = (x, y) => lid(x, y, -LID_THICKNESS);
  const display: Plane = (x, y) => lid(x - 360, 502 - y, 0.08);
  const ring = roundedRect(-WIDTH / 2, 0, WIDTH, DEPTH, 20);
  const innerFacingCamera = sin * CAMERA[1] - cos * CAMERA[2] > 0;
  const leftPort: Plane = (y, z) => [-WIDTH / 2 - 0.05, y, z];

  return (
    <svg
      viewBox="0 0 1100 710"
      role="img"
      aria-label={`Silver laptop, ${open > 0.03 ? "lid open" : "lid closed"}`}
      style={{ display: "block", width: "100%", height: "auto", overflow: "visible" }}
    >
      <defs>
        <linearGradient id={`${id}-deck`} x1="0" y1="0" x2="0.9" y2="1">
          <stop offset="0" stopColor="#e9edef" />
          <stop offset="0.5" stopColor="#d6dbde" />
          <stop offset="1" stopColor="#b8c0c5" />
        </linearGradient>
        <linearGradient id={`${id}-shell`} x1="0" y1="0" x2="0.85" y2="1">
          <stop offset="0" stopColor="#eef1f2" />
          <stop offset="0.34" stopColor="#dce2e5" />
          <stop offset="0.78" stopColor="#bdc6cb" />
          <stop offset="1" stopColor="#adb8bf" />
        </linearGradient>
        <linearGradient id={`${id}-key`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#3d4348" />
          <stop offset="1" stopColor="#272c31" />
        </linearGradient>
        <linearGradient id={`${id}-trackpad`} x1="0" y1="0" x2="0.7" y2="1">
          <stop offset="0" stopColor="#d8dde0" />
          <stop offset="1" stopColor="#c6cdd1" />
        </linearGradient>
        <linearGradient id={`${id}-glass`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0.08" />
          <stop offset="0.4" stopColor="#fff" stopOpacity="0" />
          <stop offset="1" stopColor="#a8c4d1" stopOpacity="0.025" />
        </linearGradient>
        <filter id={`${id}-contact`} x="-20%" y="-40%" width="140%" height="180%">
          <feGaussianBlur stdDeviation="9" />
        </filter>
        <clipPath id={`${id}-screen-clip`}>
          <path d={rectPath(display, 0, 0, 720, 465, 7)} />
        </clipPath>
      </defs>

      <path d={path(ring.map(([x, y]) => [x, y, -6]))} fill="#19232a" opacity={0.21} filter={`url(#${id}-contact)`} />

      {ring.map(([x, y], index) => {
        const [nextX, nextY] = ring[(index + 1) % ring.length];
        const normal: Point = [nextY - y, x - nextX];
        if (normal[0] * CAMERA[0] + normal[1] * CAMERA[1] <= 0) return null;
        const length = Math.hypot(...normal) || 1;
        const value = Math.round(142 + (normal[0] / length) * -15 + (normal[1] / length) * 15);
        const fill = `rgb(${value},${value + 8},${value + 13})`;
        return <path key={`base-${index}`} d={path([[x, y, DECK_Z], [nextX, nextY, DECK_Z], [nextX * 0.999, nextY, 1.5], [x * 0.999, y, 1.5]])} fill={fill} stroke={fill} strokeWidth={0.4} />;
      })}

      <path d={path(ring.map(([x, y]) => deck(x, y)))} fill={`url(#${id}-deck)`} stroke="#eef1f2" strokeWidth={0.9} />
      <Keyboard id={id} />

      <PlaneRect plane={leftPort} x={74} y={5} width={25} height={4.5} radius={2.25} fill="#485158" stroke="#b4bec3" strokeWidth={0.4} />
      <PlaneRect plane={leftPort} x={118} y={5} width={25} height={4.5} radius={2.25} fill="#485158" stroke="#b4bec3" strokeWidth={0.4} />
      <PlaneRect plane={leftPort} x={178} y={4.3} width={5.5} height={5.5} radius={2.75} fill="#424d54" />

      <path d={path([[-50, DEPTH, DECK_Z], [-42, DEPTH, 8.5], [-34, DEPTH, 7], [34, DEPTH, 7], [42, DEPTH, 8.5], [50, DEPTH, DECK_Z]])} fill="#79858c" />
      <path d={path([[-42, DEPTH, 8], [42, DEPTH, 8]], false)} fill="none" stroke="#dde3e5" strokeWidth={0.55} />

      <PlaneRect plane={(x, y) => [x, y, HINGE_Z - 1.8]} x={-312} y={1} width={624} height={13} radius={6} fill="#545e65" />
      <PlaneLine plane={(x, y) => [x, y, HINGE_Z - 0.9]} points={[[-300, 5], [300, 5]]} stroke="#aab5bb" width={0.8} />

      {ring.map(([x, y], index) => {
        const [nextX, nextY] = ring[(index + 1) % ring.length];
        return <path key={`lid-${index}`} d={path([lid(x, y), lid(nextX, nextY), lid(nextX, nextY, -LID_THICKNESS), lid(x, y, -LID_THICKNESS)])} fill="#a1afb8" stroke="#a1afb8" strokeWidth={0.4} />;
      })}

      {innerFacingCamera ? (
        <>
          <path d={path(ring.map(([x, y]) => inside(x, y)))} fill="#aebac1" stroke="#f3f5f5" strokeWidth={1} />
          <PlaneRect plane={inside} x={-376} y={4} width={752} height={517} radius={17} fill="#20272c" stroke="#68757d" strokeWidth={0.65} />
          <g clipPath={`url(#${id}-screen-clip)`}>
            {screen === "task" ? <TaskScreen plane={display} progress={progress} /> : <LectureScreen plane={display} />}
            <PlaneRect plane={display} x={0} y={0} width={720} height={465} radius={7} fill="#000" opacity={Math.max(0, Math.min(1, dim))} />
            <PlaneRect plane={display} x={0} y={0} width={720} height={465} radius={7} fill={`url(#${id}-glass)`} />
          </g>
          <PlaneRect plane={inside} x={-2.7} y={510} width={5.4} height={5.4} radius={2.7} fill="#111820" stroke="#536572" strokeWidth={0.4} />
          <PlaneRect plane={inside} x={-0.85} y={511.5} width={1.7} height={1.7} radius={0.85} fill="#6f8997" opacity={0.55} />
        </>
      ) : (
        <>
          <path d={path(ring.map(([x, y]) => outside(x, y)))} fill={`url(#${id}-shell)`} stroke="#eef2f3" strokeWidth={0.9} />
          <path d={rectPath(outside, -378.4, 1.6, 756.8, 521.8, 18.4)} fill="none" stroke="#a4b0b7" strokeWidth={0.35} opacity={0.6} />
        </>
      )}
    </svg>
  );
};
