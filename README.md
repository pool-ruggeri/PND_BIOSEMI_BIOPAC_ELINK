# MATLAB / Psychtoolbox / BBTK tPAD - M1 and M2

Three M1 reference scripts demonstrate optical timing, Button 1 responses,
an initial physical synchronization press, and automatic tPAD TTL event marking.
M2 adds an independent four-choice numbered-circle task using the same helpers.
The PO reports successful M1/M2 physical task tests. External TTL and full
display qualification remain pending. Hardware times come from received Mode 5 messages.

PO report (2026-10-19): M1 recovered 50 valid optical ON/OFF cycles with short
artifacts classified. The M2 physical ten-trial run recorded 9 correct,
1 incorrect, 0 timeouts, initial SYNC, 10 valid optical ON/OFF cycles, and
verified hardware RTs. These are reported lab results, distinct from automated
fixtures. See [project handoff](docs/PROJECT_HANDOFF.md) for evidence and limits.

Requirements: Windows 10, MATLAB R2023b, an existing working Psychtoolbox
installation, and a BBTK tPAD USB virtual COM connection. No Python runtime is
used. This project does not install software, change firmware, or control EyeLink.

## Configure and run

Open MATLAB in this repository. Ensure `which Screen` and `which IOPort` resolve
to the existing Psychtoolbox installation. Set `comPort = 'COM5'` at the top of
`opto_50_cycles.m`, `simple_task.m`, and `numbered_circle_task.m` to the tPAD port shown in Windows
Device Manager. COM5 is a starting value from the optional Python reference,
not a detected port. Close other applications using that port before acquisition.

Run an acquisition script directly; calibration is optional:

```matlab
opto_50_cycles
simple_task
numbered_circle_task
```

- `opto_calibration` (optional): opens a normal, movable window, approximately 700 x 500
  pixels, on black with a white 150 x 150 pixel square (or restores the saved
  position/size for that display). It uses normal stacking so you can work in
  the BBTK app at the same time. Click the calibration window to use its controls.
  Drag the square with
  the left mouse button or move it with the arrows. Press + / - to grow/shrink
  by 10 pixels per side; the main =/+ and -/_ keys and keypad + / - work.
  SPACE toggles black/white. ENTER saves `opto_patch.mat` and exits; ESC aborts
  without changing an existing configuration. Its saved position and dimensions
  affect this utility only; acquisition ignores `opto_patch.mat`. No screen measurements
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
- `numbered_circle_task` (M2): ten numbered-circle trials; press the matching
  physical Button 1..4. Its response-dependent advancement is described below.

All acquisition scripts use the same fixed **150 x 150 pixel square at the
exact bottom-left corner** of their full-screen display. `m1_patch` calculates
`[0, winH - 150, 150, winH]` from the actual window dimensions and rejects a
display smaller than 150 pixels in either dimension. No saved calibration file,
position, size, or display selection is read. The selected screen is
`max(Screen('Screens'))`; confirm it is the experimental monitor.

The patch uses RGB black `[0 0 0]` and white `[255 255 255]` in all scripts.
It remains black during synchronization, fixation, and ITI; it is white only
during each stimulus/white cycle. The actual fixed geometry is recorded in
`session.mat`. Calibration utility metadata remains independent of acquisition.
No physical centimeter size is assumed. The calibration GUI skips timing
qualification and restores its prior PTB settings on exit. By PO decision,
all acquisition scripts automatically set `SkipSyncTests=1` before opening a
window and restore the previous value on completion, error, or ESC. No preliminary
MATLAB preference command is needed. They print a warning: visual synchronization
tests are disabled and `Screen('Flip')` timestamps are not yet scientifically
qualified. Independent tPAD hardware timestamps remain unchanged.
Visual durations are rounded to the nearest whole refresh interval;
actual flip timestamps and missed deadlines are recorded.

The window uses PTB's [GUI window flag](https://psychtoolbox.org/docs/kPsychGUIWindow)
and [GlobalRect](https://psychtoolbox.org/docs/Screen-GlobalRect) for its live
client-area position. Calibration controls ignore keystrokes while the BBTK app
has focus. No keyboard suppression or serial-port ownership is requested by calibration.

## M2 numbered-circle task

Start the external recorders, run `numbered_circle_task`, and press/release
physical Button 1 at the existing synchronization screen. The SYNC timestamp
is retained separately; it cannot become a trial response. No clock reset occurs.
Targets are deterministic: `[1 2 3 4 1 2 3 4 1 2]`.

Each trial shows 1000 ms fixation, then a centered white filled circle with a
black digit for nominally 500 ms. The shared bottom-left 150 px optical patch
is white during that stimulus and black otherwise. Durations use the same
refresh-frame rounding as M1. The first fresh serial B1..B4 press is selected:
matching the digit is CORRECT; a different button is INCORRECT. Both advance
the task. Releases, additional/invalid presses, and held-button history remain logged.
The PC keyboard supplies ESC only; there is no keyboard HID response fallback.

The total response window ends 1500 ms after the stimulus onset flip, including
the first 500 ms of visible stimulus. A press processed at 200 ms is latched
immediately while the stimulus remains visible until 500 ms. A press at 900 ms
starts ITI when processed. No response leads to timeout, followed by 500 ms ITI.
A bounded **100 ms serial grace** after the nominal deadline receives split or
USB-delayed messages; it never accepts hardware RT greater than 1500 ms.
Responses received after grace remain in the logs but do not replace the trial
response. Acquisition continues during stimulus, grace, ITI, and fixation.

Online control uses parsed serial arrivals and any currently available hardware
onset match; it never waits for a complete optical pulse. `m2_response` enforces
hardware latency 0..1500 ms when an anchor exists. Without one, a candidate
whose first byte arrived in the nominal receipt window can advance provisionally.
Final `m2_trials` scoring uses the full M1 optical classification, original
hardware times, and the recorded response-close boundary. Hardware RT is
`button_press_ms - optical_on_ms`; no receipt/Flip timestamp substitutes for
a missing anchor. Missing/ambiguous onset produces `NaN` RT and explicit
unverified flags. Digit/button accuracy can still be observed, but those
receipt-based responses are not qualified hardware RTs and are excluded from
RT means. A provisional online response rejected by final hardware analysis
is flagged; advancement cannot be undone. Severe delays remain a qualification limit.

Each run uses `data/numbered_circle_task_<date>_<token>/` and the existing raw
and classified exports. `trials.csv` includes target/expected/actual buttons,
CORRECT/INCORRECT/TIMEOUT, hardware onset/offset/press/release/RT, PTB flips,
online button/hardware timestamp/accuracy, receipt/processing and close times, premature/late/extra responses,
optical artifact counts, and missing/ambiguous flags. Aborted partial windows
without a response are INCOMPLETE; untouched rows are NOT_PRESENTED. `sync.csv` and `run.sync`
save the separate synchronization event. The console reports counts, optical
availability, SYNC, RT means, and completion/abort/error status.

M2 leaves all three M1 scripts and shared acquisition code unchanged. It sets
and restores `SkipSyncTests=1`, with the same unqualified-display-timing warning.
Automatic hardware TTL configuration/wiring remains untouched for all four
buttons and Optical 1; physical mapping, optical artifacts, and external TTL
receipt still require laboratory qualification. EyeLink integration is deferred.

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

All acquisition scripts classify Optical 1 reports after raw parsing with
`m1_classify_optical`. Consecutive Optical 1 ON/OFF records form complete pulse
pairs in serial order, ignoring interleaved buttons. An intended pulse must
have its ON and OFF in the corresponding presentation receipt gates, with
hardware duration within the existing **50 ms** tolerance of the displayed
white interval (approximately 500 ms). A short pair is classified as chatter
only if it lasts **0..3 ms**, adjoins an intact intended pulse at onset or
offset, and the entire burst spans at most **20 ms** from that transition.
All burst records must share that transition's ON or OFF receipt gate and be
chronological and free of duplicate/state errors. Multiple short pairs and
zero-ms ON/OFF/ON are supported. Independently intended short pulses are
protected by their own distinct ON/OFF gates. Startup, unfinished, distant,
or unsupported pairs remain unresolved; short duration alone never excludes a pair.

All measured pulse durations and burst gaps use original tPAD milliseconds.
Host receipt gates provide intended-transition context only; no clocks are
aligned or substituted. Duplicate detection requires a repeated identity
**without an intervening opposite edge on that sensor**. Equal-ms ON/OFF/ON
and OFF/ON/OFF are real ordered transitions, not duplicates. No raw record,
hardware timestamp, event order, or button event is deleted or rewritten.

`optical_class` distinguishes `VALID_OPTICAL_ON/OFF`,
`IGNORED_OPTICAL_GLITCH_ON/OFF`, unresolved and invalid reports; `optical_glitch`
marks analysis exclusions. VALID means part of an intact intended pulse, not hardware
qualification. Raw and filtered counts and ignored-pair totals are reported
separately. Raw totals include setup/startup; filtered validation counts cover
the interval from the first intended optical flip through the final drain.
`pulse_recovery_result` requires complete intended pulses, unique ordered edge
matches, correct totals/durations, and no unresolved anomalies. The original
`result` additionally requires no missed scheduled flips. Neither is physical
TTL qualification; a separate warning reports raw artifacts even after recovery.

Read-only replays of the PO's two 2026-10-16 recordings give:

| Recording time | Raw ON/OFF | Valid ON/OFF | Short artifacts (onset/offset) | Long durations | Pulse recovery |
| --- | --- | --- | --- | --- | --- |
| 10:51:38 | 61/61 | 50/50 | 11 (2/9), 0..2 ms | 502..505 ms | PASS |
| 11:51:33 | 55/55 | 50/50 | 5 (1/4), 0..3 ms | 502..506 ms | PASS |

Both have zero missing pulses/unresolved events. Their full checks remain FAIL:
each recorded one missed first-ON flip deadline (about 15.9 ms). The earlier
10:11:38 recording also reconstructs 50 pulses plus 13 artifacts (1..3 ms),
with full checks PASS; complete-pulse analysis resolves its previously ambiguous
onset bursts. Counts are calculated from records, never forced to 50/50.

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
Software exclusions cannot remove TTL pulses already emitted by the tPAD;
external recorders may retain those short pulses. Sensitivity/threshold behavior
is suspected, not established. The PO is consulting BBTK; physical optical/TTL
cleanliness remains unqualified until sensitivity and trigger output are tested.

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
| `raw_messages.csv` | Decoded records before optical/trial postprocessing; `run.raw_messages` retains live sync markers |
| `messages.csv`, `events.csv` | All parsed messages/events, raw hex, flags, labels, optical classifications |
| `optical_events.csv`, `optical_matches.csv` | Optical reports and per-transition matches/missing values |
| `optical_pulses.csv` | Complete hardware pulse pairs, durations, intended/onset-artifact/offset-artifact/unresolved classes |
| `flips.csv`, `trials.csv`, `summary.csv` | PTB timestamps, task responses, run counts/results |
| `optical_summary.csv` (task) | Raw/filtered optical totals, matches, ignored pairs, unexpected optical reports |
| `status.txt` | Completion/abort/error status and failure text |

CSVs for empty categories are omitted; `session.mat` preserves empty/partial
categories. `NaN` means unavailable, never zero-filled hardware data. A final
500 ms drain collects pending reports even after ESC. A force-terminated process
or power loss may leave only raw journals; journal flushing is not crash-proof.
Generated data and calibration are ignored by Git.

```matlab
addpath('tests')
run_offline_tests
run_optical_filter_tests
run_numbered_circle_tests
run_script_smoke_tests
run_lab_replay
```

The script smoke test runs copies with isolated synthetic PTB/serial functions
under `.local/script_smoke/`; it opens no real hardware and restores the MATLAB
path afterwards. Do not add `.local` or this whole repository recursively to
the MATLAB path. See [handoff](docs/PROJECT_HANDOFF.md) for actual results.
The replay reads both named recordings and the earlier 10:11 run without
overwriting them, exporting new analysis under `.local/lab_replay/`. Missing
Git-ignored recordings are explicitly skipped. Passing replay regressions
verify pulse reconstruction and preserve the separate full-check failures;
they do not establish hardware qualification.

If the port cannot open, check Device Manager and close the BBTK app/terminals.
The known COM5 conflict is the BBTK app owning the port. Failed acquisition
reports the port error, closes resources, and skips cleanup drawing after a
serial failure. Final redraws also check that the window is still open. The
scripts do not terminate the BBTK app automatically.
Serial and journal ownership is shared with the exit guard: explicit close,
abort/error cleanup, and repeated stale cleanup release each resource once.
Handle 0 is accepted while owned; a stale guard cannot close a reused handle.
Missing mode acknowledgement stops acquisition and saves the error. For missing
optical events, check patch placement, sensor sensitivity, and the BBTK sensor
check utility. The acquisition scripts already set `SkipSyncTests=1`; persistent
display failures still need investigation. Inspect raw messages, missed flips,
and run status when a test fails. No automatic timestamp correction is applied.
