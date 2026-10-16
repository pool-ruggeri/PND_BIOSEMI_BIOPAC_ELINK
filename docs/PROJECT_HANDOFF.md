# M1 project handoff

Delivery date: 2026-10-15; updated 2026-10-16 (Europe/Zurich). Status: software implemented; laboratory
acceptance pending. Roles: PO = user; TL = ChatGPT; implementation = Codex.

## Architecture and scope

`tpad_parse.m` incrementally decodes text XiD messages. `tpad_io.m` owns IOPort
polling and raw journals. `m1_match_optical.m` and `m1_trials.m` associate reports
and calculate hardware-only RTs. Small display, patch, wait, cleanup, and log
functions support the three scripts. MATLAB/PTB seconds, tPAD milliseconds,
and host serial-reception times remain separate fields.

The PO's M1 scope is recorded in [DECISIONS.md](DECISIONS.md). All three scripts
are implemented. The optional Python reference was read only. No external
recording-system control, installation, firmware change, or cabling work occurred.

PO fixed-patch decision (2026-10-16): both acquisition scripts now open without
calibration and calculate the same 150 x 150 px bottom-left square from the
actual full-screen window size: `[0, winH - 150, 150, winH]`. `m1_patch` is the
small shared geometry helper; `m1_display` has no saved-patch validation.
RGB black/white remain `[0 0 0]` / `[255 255 255]`. The patch is black outside
stimuli/white cycles. Calibration is optional and unchanged; its saved file,
coordinates, dimensions, and display selection are never read by acquisition.

The PO identified BBTK holding COM5 as the serial-open failure cause. Each
script reports a single clear port failure with the instruction to close the
port owner. Cleanup skips drawing after a serial failure and checks live window
handles before other final redraws. Invalid negative serial handles are not
closed. Resources and prior sync preferences are restored; BBTK is not terminated.
XiD protocol, hardware timestamps, automatic TTL, matching, trial/cycle schedule,
and log writers are unchanged.

PO hotfix (2026-10-16): the laboratory PC reported a VBL synchronization failure
in `opto_50_cycles`. Both acquisition scripts now set `SkipSyncTests=1` before
opening any PTB window; `onCleanup` restores the previous value on completion,
errors, or aborts. `m1_display` no longer overrides the caller's setting with 0.
Run `opto_50_cycles` or `simple_task` directly without preliminary preference
configuration. Both print that visual synchronization tests are disabled and
`Screen('Flip')` timestamps are not yet scientifically qualified. Independent
tPAD timestamps, XiD, TTL, optical matching, trial structure, and logging are
unchanged. `opto_calibration.m` is unchanged.

PO hotfix (2026-10-15): `opto_calibration.m` now opens a normal, movable window
approximately 700 x 500 px, with a 150 px white square on black and normal stacking.
Mouse drag and arrows position it, +/- resize
it, SPACE toggles black/white, ENTER saves, and ESC exits without writing.
Saving queries the current window client-area origin, including title-bar and
window movement, to produce absolute `desktop_rect`. Subtracting the monitor's
desktop origin yields `rect` for this optional utility only.
The window-local rectangle, monitor/window global rectangles, and `size_px`
are retained. The patch must remain on the selected display when saved.

PTB 3.0.19's key-name table can contain numeric empty cells. All calibration
alias maps now filter non-text entries before using `ismember`. Both other
scripts and their helpers were inspected: direct `KbName` lookups have no
analogous mixed-table membership call. GUI controls ignore BBTK keystrokes when
unfocused. Calibration uses no serial connection or keyboard suppression.
Normal stacking applies only to this GUI, which retains its separate
`SkipSyncTests=2` setting and restores prior preferences even on cancel. Scheduled durations,
XiD acquisition, hardware timestamps, TTL, and trial/cycle logic are unchanged.

Serial: editable COM5 default in both acquisition scripts; 115200, 8N1, no flow
control; nonblocking reads; acknowledged command mode followed by Mode 5;
minimum 25 ms command spacing. No explicit timer reset or event-to-TTL writes.

## Evidence and limits

Manufacturer documentation confirms the text/CRLF event protocol, A/C/M/T
channels, P/R edges, and hardware TTL mapping: Button 1 -> TTL Out 1 and
Optical 1 -> TTL Out 11 on TTL I/O 1. These are documentary facts, not a
measurement of this unit. Active sensitivity, smoothing, TTL voltage/edges,
and actual trigger receipt by BioSemi/BIOPAC/EyeLink remain unverified.

MATLAB R2023b Update 1 runs using its existing network license when network
access is available. Preferences for checks were confined to `.local/`.
The initial restricted launch failed to contact the license server; a permitted
retry succeeded. `Screen` and `IOPort` did not resolve on the default R2023b
path. Agent checks installed no software and opened no real PTB display or
serial port. The PO reported that windowed calibration works; the subsequent
physical attempts exposed VBL synchronization failure and BBTK holding COM5.
The fixed-patch build has not yet been physically retested.

Final checks on MATLAB R2023b Update 1 passed:

- 11 offline test groups, including 123 two-read split positions, bytewise
  input, malformed/unfinished/overlong messages, original timestamps,
  duplicate/reversed edges, missing/wrong/late optical reports, delayed
  responses/releases across trial boundaries, missing-onset RT handling,
  missing responses, and MAT/CSV exports including scalar early-failure data.
- 22 simulated script scenarios plus geometry bounds checks: both acquisition
  scripts run before calibration has ever executed; later saved calibration
  geometry and malformed utility output are ignored. Both use `[0 930 150 1080]`
  on 1920 x 1080; the helper returns `[0 618 150 768]` on 1024 x 768 and rejects
  an undersized display. Checks cover RGB values, 50 alternating 500 ms cycles,
  50/50 received optical reports, black task synchronization/fixation/ITI,
  ten trials, hardware RTs, synchronization, and the Mode 5 command allowlist.
- Failure cases cover missing optical data/onset, ESC, disconnection, window
  open errors, occupied COM5 with both live and already-closed windows, thrown
  and returned serial-open errors, invalid serial handles, and unexpected
  display closure. Checks require one serial error report, zero invalid redraws,
  no journal-file leaks, and restored sync preferences (initial 0, 1, and 2).
- Existing optional-calibration tests still cover mixed key-name cells, window
  movement, primary/secondary desktop coordinates, focus, controls, and saving
  or byte-for-byte preservation on ESC. The calibration source is unchanged.
- MATLAB Code Analyzer: zero findings across all 14 MATLAB source/test files.
  Intentional test-only shared state has explicit analyzer annotations.

The synthetic `input` stub produces an expected built-in-shadowing warning.
Test code restores the prior MATLAB folder/path. Full console output is in
`.local/fixed_patch_checks.log`; test artifacts are ignored by Git. Synthetic test
success does not qualify physical timing or trigger delivery.

Known limits: single selected display/sensor/button, frame-quantized durations,
disabled visual synchronization tests and unqualified PTB Flip timestamps,
250 ms receipt matching bound, 50 ms optical duration tolerance, no clock drift
or wrap correction, no release beyond the final drain, and no guaranteed recovery
after power loss/forced process termination. Severe latency makes fixation/ITI
context less certain even when hardware RT remains recoverable.

## Local Git

Branch: `main`. Baseline M1 is commit `cbad781153ce7700d2e3aa413cee57fa8b99b026`,
tagged `m1`. Prior pixel UX correction: `0ca0c32`; window/keyboard hotfix: `321c800`.
Sync-preference hotfix: `39a393e`. The fixed-patch hotfix is the latest commit
touching `m1_patch.m`: `git log -1 --format=%H -- m1_patch.m`.
No remote is configured and no push is part of this work.

## Exact next steps for PO acceptance

1. Make the existing Psychtoolbox installation available on the R2023b path;
   check `which Screen` and `which IOPort`. Set the actual COM port in both
   acquisition scripts. Both set `SkipSyncTests=1` automatically; no preliminary
   MATLAB preference configuration is required. PTB timing qualification remains pending.
2. Confirm the physical sensor covers the bottom-left 150 x 150 px area of the
   selected experimental monitor. Calibration is optional for BBTK sensitivity
   adjustment; its saved position does not configure acquisition. Record the
   installed firmware, sensitivity, and smoothing settings. Close the BBTK app
   or release its COM port before acquisition. Verify a deliberately occupied
   port produces one clear error and safe cleanup on the laboratory PC.
3. Run `opto_50_cycles`; require 50 ON, 50 OFF, all matched in sequence,
   zero anomalies, and optical result PASS. Inspect actual durations and flips.
4. Start the external recorders. Run `simple_task`, press/release physical
   Button 1 once to synchronize, and perform ten trials. Confirm the separate
   sync event, optical edges, hardware RTs, missing/premature responses, and
   press/release pairing. Repeat with an ESC abort and inspect partial outputs.
5. With the existing approved wiring, physically verify automatic Button 1 and
   optical onset/offset TTL transitions and their recording in each acquisition
   system. Record measurements/settings and PO acceptance before M2.

M2 may add the PTB EyeLink interface after acceptance, reusing the tPAD reader.
There is no implementation blocker; physical acceptance needs PO laboratory
access and the existing PTB/hardware setup.
