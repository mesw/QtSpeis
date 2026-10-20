# QtSpeis: Non-Linear Temporal Dial & Spiral Schedule Visualization

> **Status:** Experimental UI & Design Study / Prototype
>
> **Core Concept:** A non-linear temporal visualization displaying time on a circular or spiral dial with continuous focus-plus-context ("fish-eye") zooming—keeping the complete global schedule visible at all times while enabling high-resolution inspection of local intervals.

---

### Origin & Motivation
This experimental UI sparked from the idea of displaying a timeline on a circular display, allowing intuitive 24-hour clock navigation while enabling users to zoom into specific times of the day without ever losing sight of the overall 24-hour cycle.

It was originally conceived as a **design study and prototype for a weekly meal planning application** to explore alternatives to traditional linear or grid-based calendar views. Having served its exploratory purpose, the resulting visualizations offer an interesting paradigm for specialized scheduling, agenda inspection, or circular display form factors.

---

### Visualization Modes

1. **24-Hour Circular Dial View (`TemporalPieChart`)**
   - Represents a continuous 24-hour cycle as a circular dial (12:00 noon south, 00:00 midnight north).
   - Supports **non-linear angular warping (temporal fish-eye lens)**: zoom into busy periods with magnified angular resolution while the remaining hours smoothly compress without clipping.
   - Diurnal / circadian blended lighting reflecting day, twilight, and night.
   - Hierarchical concentric tracks: parent/macro activities on the inside ring, child tasks expanding to outer rings.
   - Live system clock synchronization ("Follow Time" mode).

2. **Multi-Day Spiral Timeline (`TemporalSpiralChart`)**
   - Extends the circular timeline into a coiled spiral to visualize an entire weekly schedule (supporting both 7-day week and 3-day / 72-hour rolling modes).
   - **Coincident Radial Time Alignment**: For every winding of the coiled spiral, times overlap radially—12:00 noon always points south across all days, and 00:00 midnight always points north.
   - Rolling layout: the current day sits on the outer winding, with future days coiling progressively inwards.
   - It is an interesting visual concept, though it takes time to get used to compared to conventional calendar views.

---

### Features & Capabilities

- **Hierarchical Schedule Visualization:** Supports multi-level task/event structures (Root categories, sub-tasks, and discrete point milestones/reminders).
- **High-Contrast Non-Overlapping Callout HUD:** Hovering over any time interval displays a floating activity callout card detailing all concurrent broadcasts/tasks at that exact time with WCAG AAA contrast and collision-free layout.
- **Dynamic Real-World Data Source (TV Program Fetcher):**
  - Includes a refresh button to fetch live TV program schedules from [tv.orf.at (ORF 1)](https://tv.orf.at/program/orf1/) across all 7 days of the week.
  - Serves as an ideal dynamic data source to test multi-level hierarchy, diverse event durations, and schedule wrapping.
- **YAML-Based Schedule Definition & Live Editing:**
  - Full schedule data can be authored and edited in human-readable YAML format.
  - Integrated built-in YAML editor panel with real-time model parsing and instant visual updates.

---

### Important Scope & Current Limitations

> [!NOTE]
> **This is a design study and visualization viewer.**
> - It served its original purpose as an exploratory prototype.
> - **Interaction Scope:** Focused on viewing, inspection, zooming, panning, and live time-tracking.
> - **Editing Controls:** There are currently **no direct-manipulation editing controls** on the dial (e.g., no dragging edge handles to resize durations or click-and-drag slice creation).
> - Schedule modifications are currently performed exclusively through the YAML editor panel.

---

### Live Online Demo (WebAssembly)
This prototype can be hosted online on GitHub Pages via WebAssembly:
- [Launch WebAssembly Demo](build/WebAssembly_Qt_6_8_3_single_threaded-Release/index.html)

---

### Building Locally

#### Desktop (Qt 6.8+ / MinGW / Clang / MSVC)
```bash
cmake -B build -S .
cmake --build build
```

#### WebAssembly (Qt 6.8+ WASM & Emscripten)
```bash
call <path-to-emsdk>/emsdk_env.bat
qt-cmake -B build/WebAssembly_Qt_6_8_3_single_threaded-Release -S . -GNinja
cmake --build build/WebAssembly_Qt_6_8_3_single_threaded-Release
```
