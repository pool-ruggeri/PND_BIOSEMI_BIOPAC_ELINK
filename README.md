# MATLAB / Psychtoolbox / BBTK tPAD - M1

Three small reference scripts demonstrate optical timing, Button 1 responses,
an initial physical synchronization press, and automatic tPAD TTL event marking.
Hardware acceptance is pending. All reported hardware times must come from
received Mode 5 messages.

Requirements: Windows 10, MATLAB R2023b, an existing working Psychtoolbox
installation, and a BBTK tPAD USB virtual COM connection. No Python runtime is
used. This project does not install software, change firmware, or control EyeLink.

## Configure and run

Open MATLAB in this repository. Ensure `which Screen` and `which IOPort` resolve
to the existing Psychtoolbox installation. Set `comPort = 'COM5'` at the top of
**both** `opto_50_cycles.m` and `simple_task.m` to the tPAD port shown in Windows
Device Manager. COM5 is a starting value from the optional Python reference,
not a detected port. Close other applications using that port before acquisition.

Run the following individually, in order:

```matlab
opto_calibration
opto_50_cycles
simple_task
```

- `opto_calibration`: opens a normal, movable window, approximately 700 x 500
  pixels, on black with a white 150 x 150 pixel square (or restores the saved
  position/size for that display). It uses normal stacking so you can work in
  the BBTK app at the same time. Click the calibration window to use its controls.
  Drag the square with
  the left mouse button or move it with the arrows. Press + / - to grow/shrink
  by 10 pixels per side; the main =/+ and -/_ keys and keypad + / - work.
  SPACE toggles black/white. ENTER saves `opto_patch.mat` and exits; ESC aborts
  without changing an existing configuration. Keep the patch clear of the
  central fixation/stimulus and synchronization text. No screen measurements
  or console prompts are required. Use the existing BBTK app to adjust optical
  sensitivity; this script uses no serial port or sensitivity algorithm. Set
  `screenNumber` at the top if needed, and keep the square on that display.
- `opto_50_cycles`: presents 50 white/black cycles, nominally 500 ms per state,
  and reports measured ON/OFF events plus sequence and timing errors. A
  completed presentation can still have a FAIL result. Leave the buttons alone.
- `simple_task`: start the external recorders first, then press and release
  physical tPAD Button 1 at the synchronization screen. Ten trials follow:
  1 s fixation, 500 ms stimulus, a response window through 1500 ms after onset,
  and 500 ms ITI. Respond with Button 1. ESC saves partial data and exits.

The acquisition scripts reuse the saved display, position, dimensions, and RGB
black `[0 0 0]` / white `[255 255 255]`. Repeat calibration after changing the
display, its resolution, or scaling. `desktop_rect` saves absolute desktop
coordinates using the current window client-area location, including window
movement. `rect` gives the same position within the selected display for both
full-screen scripts; `calibration_rect` is the window-local rectangle, and
`size_px` is its pixel size. Saving rejects a patch outside the selected display.
No physical centimeter size is assumed. The calibration GUI skips timing
qualification and restores its prior PTB settings on exit; acquisition sync
checks remain enabled. Visual durations are rounded to the nearest whole refresh interval;
actual flip timestamps and missed deadlines are recorded.

The window uses PTB's [GUI window flag](https://psychtoolbox.org/docs/kPsychGUIWindow)
and [GlobalRect](https://psychtoolbox.org/docs/Screen-GlobalRect) for its live
client-area position. Calibration controls ignore keystrokes while the BBTK app
has focus. No keyboard suppression or serial-port ownership is requested by calibration.

## Serial, timing, and TTL

The reader uses IOPort at 115200 baud, 8N1, with no flow control and explicitly
nonblocking reads. Initialization sends `X`, checks `MODE 0:`, waits at least
25 ms, sends `MOD5` plus CR/LF, and checks `MODE 5:`. It sends no timer resets
or software TTL commands. Events are text lines such as `A P 1 123456`;
`A` identifies buttons, `C` optical sensors, and `P`/`R` activation/deactivation.
Raw bytes and original hardware milliseconds are retained.

Optical events are associated with a displayed edge only when their first
received bytes fall within 250 ms after that flip and before the next edge.
This is a conservative receipt gate, **not a clock synchronization estimate**.
Unmatched, ambiguous, duplicated, malformed, or reversed events remain visible.
The optical test also checks consecutive hardware/display duration differences
against a 50 ms tolerance and fails for missed scheduled flips.

Task RT is `(button_press_ms - optical_on_ms)`, using only hardware timestamps,
with a 0..1500 ms window and serial event order to break equal-ms onset ties.
The first eligible press is selected; releases are paired across trial boundaries.
A missing optical onset produces an unverified button candidate and `NaN` RT,
never a PTB substitute. Fixation/ITI context for other presses uses host receipt
times; severe serial delays can make that context uncertain. There is no drift
correction or timer-wrap repair. A backwards hardware timestamp is flagged.

The manufacturer documents automatic mirroring on TTL I/O 1: Button 1 uses
pin 1 / TTL Out 1; Optical Sensor 1 uses pin 5 / TTL Out 11; pin 8 is ground.
Activation raises the output and deactivation lowers it. Existing smoothing
settings can affect physical trailing edges. The code leaves those settings
unchanged. Record and verify the installed settings with the BBTK app during
laboratory acceptance. No cabling changes are part of M1. Receipt by BioSemi,
BIOPAC, and EyeLink has **not** been physically verified.

Protocol sources: [BBTK tPAD manual](https://www.blackboxtoolkit.com/docs/pdf/TPadv1r1.pdf),
sections 2.2, 7, 11.10, 11.12, 12.2, 17, and 18.5;
[IOPort Read](https://psychtoolbox.org/docs/IOPort-Read),
[OpenSerialPort](https://psychtoolbox.org/docs/IOPort-OpenSerialPort), and
[Write](https://psychtoolbox.org/docs/IOPort-Write).

## Outputs and checks

Each acquisition creates a unique folder under `data/`:

| File | Contents |
| --- | --- |
| `session.mat` | Authoritative complete/partial run, configuration, sync marker, matches, errors |
| `raw_rx.bin`, `raw_chunks.csv` | Exact received bytes, zero-based offsets, read/poll host times |
| `commands.csv` | Initialization bytes in hex and host send times |
| `messages.csv`, `events.csv` | Parsed messages and events, raw line hex, anomaly flags, labels |
| `optical_events.csv`, `optical_matches.csv` | Optical reports and per-transition matches/missing values |
| `flips.csv`, `trials.csv`, `summary.csv` | PTB timestamps, task responses, run counts/results |
| `status.txt` | Completion/abort/error status and failure text |

CSVs for empty categories are omitted; `session.mat` preserves empty/partial
categories. `NaN` means unavailable, never zero-filled hardware data. A final
500 ms drain collects pending reports even after ESC. A force-terminated process
or power loss may leave only raw journals; journal flushing is not crash-proof.
Generated data and calibration are ignored by Git.

```matlab
addpath('tests')
run_offline_tests
run_script_smoke_tests
```

The second test runs script copies with isolated synthetic PTB/serial functions
under `.local/script_smoke/`; it opens no real hardware and restores the MATLAB
path afterwards. Do not add `.local` or this whole repository recursively to
the MATLAB path. See [handoff](docs/PROJECT_HANDOFF.md) for actual results.

If the port cannot open, check Device Manager and close the BBTK app/terminals.
Missing mode acknowledgement stops acquisition and saves the error. For missing
optical events, check patch placement, sensor sensitivity, and the BBTK sensor
check utility. For PTB timing failures, resolve the existing display setup before
collecting data; do not disable sync checks. Inspect raw messages, missed flips,
and run status when a test fails. No automatic timestamp correction is applied.
