# M1 / M2 project handoff

Delivery date: 2026-10-15; updated 2026-10-19 (Europe/Zurich). Status: M1/M2
implemented and physical task tests reported successful; external TTL and full
display qualification pending. Roles: PO = user; TL = ChatGPT; implementation = Codex.

## Current laboratory evidence and remaining qualification

The following is Product Owner laboratory evidence reported on 2026-10-19,
separate from the automated tests recorded below. The agent did not conduct
these physical measurements or rerun hardware during publication preparation.

- M1: optical calibration utility implemented; the 50-cycle optical test was
  physically validated, with 50 valid optical ON/OFF cycles recovered. Short
  optical artifacts were identified and classified; original hardware records
  remain available locally. Successful reconstruction does not establish clean
  physical TTL output.
- M2: `numbered_circle_task.m` supports four physical buttons through Mode 5 XiD
  serial and records the initial synchronization event. The physical ten-trial
  test completed successfully: **9 correct, 1 incorrect, 0 timeouts**, with
  **10 valid optical ON/OFF cycles**. Hardware-based reaction times were verified
  by the PO. These are physical-run results, not the 5/1/4 synthetic fixture.
- Remaining: external TTL verification with BioSemi, BIOPAC, and EyeLink; full
  display timing qualification; EyeLink 1000 Plus software integration; and the
  BBTK optical sensitivity investigation. No external-system integration or
  hardware-setting changes are included in publication.

## GitHub publication and future workflow

On 2026-10-19 the PO explicitly lifted the local-only restriction and authorized
a private GitHub repository named `PND_BIOSEMI_BIOPAC_ELINK`, using remote
`origin`. Publication must preserve the existing M1/M2 history and `m1` tag,
without force-push, history rewriting, or an independent GitHub initial commit.
Repository ownership/authentication and remote synchronization must be verified
before publication is reported complete.

Publication preparation is complete locally. Initial repository creation/push
is pending verification of the intended owner and matching Git credentials;
no `origin` has been configured at this preparation stage.

GitHub is the canonical project repository from this publication milestone.
For each accepted implementation milestone: update this handoff and the decision
log, run appropriate checks, commit locally, push the relevant branch, and
verify synchronization. Use the existing main-branch workflow; no new branching
strategy, CI pipeline, or administrative framework is introduced.

Publish source, helpers, automated tests, documentation, and necessary project
configuration only. `.gitignore` excludes acquisition directories, raw/derived
data formats, calibration/workspace MAT files, logs, MATLAB caches, temporary
files, and credential files. Experimental recordings remain local and must not
be added without explicit publication approval. No local recordings were deleted.

## Architecture and scope

`tpad_parse.m` incrementally decodes text XiD messages. `tpad_io.m` owns IOPort
polling and raw journals. `m1_classify_optical.m` annotates optical exclusions
without changing records. `m1_match_optical.m` and `m1_trials.m` associate reports
and calculate hardware-only RTs. Small display, patch, wait, cleanup, and log
functions support the three scripts. MATLAB/PTB seconds, tPAD milliseconds,
and host serial-reception times remain separate fields.

The PO's M1 scope is recorded in [DECISIONS.md](DECISIONS.md). All three scripts
are implemented. The optional Python reference was read only. No external
recording-system control, installation, firmware change, or cabling work occurred.

## M2 numbered-circle delivery

`numbered_circle_task.m` is the new independent executable. Set its `comPort`
and run `numbered_circle_task` directly. All M1 scripts and production helpers
are unchanged from `56985a5`. M2 reuses their serial/optical/display/cleanup/log
functions, adding `m2_response.m` for eligibility and `m2_trials.m` for four
buttons, accuracy, and original-hardware RT. The deterministic targets are
`[1 2 3 4 1 2 3 4 1 2]`; digit N requires physical serial Button N.

Initial Button 1 SYNC press/release is preserved, with no clock reset. Trials
show 1000 ms fixation, 500 ms numbered circle, and a total 1500 ms response
window measured from visual onset. The first parsed fresh B1..B4 press controls
advancement; incorrect buttons advance just like correct buttons. An early
press never truncates the stimulus. After offset, a response advances directly
to 500 ms ITI; timeout waits only to onset+1500 ms plus 100 ms serial grace.
The patch remains the shared fixed bottom-left 150 px black/white square.
Visual durations retain M1's frame rounding; PTB timing remains unqualified.

Live control never waits for optical pair completion. It uses any available
onset match to reject hardware latency outside 0..1500 ms; otherwise it latches
a receipt-window candidate provisionally. Final analysis runs the full M1
optical classifier and computes RT only from retained ON and button hardware
timestamps. Missing/ambiguous onset yields NaN RT and unverified response flags.
Those observable digit/button responses can contribute accuracy, not RT means.
Online control timestamps and a final-rejection flag expose any disagreement.
Messages first received after deadline without a hardware anchor cannot qualify;
hardware RT >1500 ms is always late. Grace receives bytes without extending the
participant window. Final candidates must arrive before the recorded close
boundary; reports beyond grace remain logged. No clocks are aligned/invented.

Outputs use a unique `data/numbered_circle_task_*` folder and all existing raw,
classified, pulse, flip, summary, and trial exports. New trial columns include
digit/expected/actual button, outcome, four-button release pairing, hardware
onset/offset/press/RT, live button/hardware timestamp/accuracy and
receipt/processing/close/ITI times, artifact pairs,
premature/late/extra, missing/ambiguous, and online-rejection flags. `sync.csv`
separately exports `run.sync`. Completed no-response windows are TIMEOUT;
aborted partial windows without a response INCOMPLETE, and untouched trials
NOT_PRESENTED. Responses already acquired before abort remain preserved.

M2 software validation on MATLAB R2023b Update 1:

- Six focused analysis groups cover all four correct channels, incorrect input,
  exact hardware deadline and grace bounds (1490/1500 accepted, 1501 rejected),
  missing/ambiguous optical onset, equal-ms stream order, extra responses,
  per-button releases, and incomplete/unpresented rows.
- Seven synthetic real-script scenarios cover normal ten-choice runs, mixed
  inputs, ESC, disconnect inside the response loop, occupied COM5, window-open
  failure, and unexpected display closure. All use valid serial handle 0,
  reject double closes, check restored preferences/no file leaks/no invalid
  redraws, and verify exact raw chunk offsets after exceptions.
- The mixed ten-trial fixture produces 5 correct, 1 incorrect, 4 timeouts;
  hardware means are 522.5 ms correct / 598 ms all-response. It covers early
  200 ms and late 900 ms advancement, held/premature B2 spanning trials,
  extra presses, 2 optical artifact pairs, missing-onset NaN RT, and a 1490 ms
  physical press received after 1500 ms. Stimuli stay 500 ms, fixation 1000 ms,
  deadline is onset+1500 ms, and PC/HID key states never become responses.
  A delayed fixation press initially seen before optical ON parsing is rejected
  once that anchor arrives; stale provisional control timestamps are cleared.
- All existing M1 tests still pass: 30 script scenarios, 11 offline groups
  including 123 split positions, 10 optical groups, and all three historical
  raw replays. Their recorded missed-flip/full-check failures remain preserved.
- Code Analyzer: zero findings across 21 source/test files. Logs:
  `.local/m2_analysis_checks.log`, `.local/m2_script_checks.log`.

The implementation agent performed no physical GUI, tPAD, TTL, or external-recorder
validation. The later successful PO physical M2 run is recorded in the current
evidence section above. The automated abort/held-button/error scenarios remain
software checks unless separately measured in the laboratory. Sensitivity,
physical TTL cleanliness, external trigger receipt, and scientifically qualified
visual timing remain pending. EyeLink 1000 Plus integration remains future work.

M2 local commit: latest touching `numbered_circle_task.m`:
`git log -1 --format=%H -- numbered_circle_task.m`: `b47b0ea`.
Its original local-only restriction was superseded by the 2026-10-19 publication authorization.

## M1 retained evidence

PO sequence-classification correction (2026-10-16): inspected and replayed
both requested physical recordings from exact raw bytes and chunk receipt times:

- Recording 1: `data/opto_50_cycles_20261016_105138_tp4904ffea_6e55_43ed_a961_4b0a28b01c2d`.
- Recording 2: `data/opto_50_cycles_20261016_115133_tp22f4ba43_8327_4209_acda_31dda354e243`.

| Replay metric | Recording 1 | Recording 2 |
| --- | --- | --- |
| Raw ON/OFF | 61/61 | 55/55 |
| Valid intended pulses / matched ON/OFF | 50 / 50/50 | 50 / 50/50 |
| Short artifact pairs (onset/offset) | 11 (2/9) | 5 (1/4) |
| Artifact hardware duration | 0..2 ms | 0..3 ms |
| Recovered long hardware duration | 502..505 ms | 502..506 ms |
| Missing pulses / unresolved events | 0 / 0 | 0 / 0 |
| Intended pulse recovery | PASS | PASS |
| Missed flip deadlines / full checks | 1 / FAIL | 1 / FAIL |

Both missed flips are first-ON transitions, with reported missed_s approximately
15.86/15.88 ms. This display issue remains visible; software pulse recovery is
separate from full checks and physical timing/TTL acceptance. The previous
analysis reported 3/3 duplicate/state errors in recording 1 and 1/1 in recording
2. Corrected parsing reports 0/0 in each. The original global identity check
mistook repeated P at the same ms after R for a duplicate, skipped the state
update, and falsely flagged the subsequent long-pulse R. An intervening opposite
edge now establishes a new transition. Same-level repeated identities remain
flagged and retained. The extra short pulses are present in raw serial data;
they were not manufactured by MATLAB.

The classifier now builds complete adjacent Optical 1 P/R pairs in original
order. A valid intended pulse has P/R in its corresponding ON/OFF receipt gates
and hardware duration within the existing 50 ms tolerance of the displayed
white interval (approximately 500 ms). Only complete 0..3 ms pairs adjoining
that intact pulse can be artifacts: all pairs must share its onset or offset
gate, contain no duplicate/order/state errors, and fit a total burst span of
20 ms from the anchor ON or OFF. Multiple pairs, zero-ms ON/OFF/ON, and
OFF/ON/OFF are supported. Separate intended transitions retain their own gates.
Startup, incomplete/missing, distant and unsupported records remain unresolved;
no events or timestamps are invented. The 250 ms receipt gate is only context;
all measured pulse durations and burst gaps use original tPAD milliseconds.

The earlier `data/opto_50_cycles_20261016_101138_tp8074c4e9_ed58_4b9e_9dae_55037be1da10`
also replays: 63/63 raw -> 50 intended pulses, 13 artifacts (2 onset/11 offset,
1..3 ms), 501..504 ms long pulses, no missing/unresolved events, and full PASS.
This supersedes the 52/52 retained / 2 missing / 6 unexpected conservative
post-OFF-only result in `4bc74a3`; thresholds were not expanded to force counts.

Raw bytes, record order, hardware/receipt times, channels, and edges reproduce
the originals exactly. Duplicate/state flags are corrected annotations; old
sessions remain untouched. `run.raw_messages`/`raw_messages.csv` retain the
decoder output before optical/trial postprocessing (including live sync markers)
separately from classified `run.messages` and
existing event CSVs. `run.optical_pulses`/`optical_pulses.csv` retain complete
pairs, measured durations, and intended/onset-artifact/offset-artifact/unresolved
classes. Raw totals include startup; validation retains the first-optical-flip
through final-drain interval. Both scripts use the classifier after acquisition.
Task synchronization, response pairing, ten-trial structure, and RT formula
are unchanged. RT uses the actual ON starting the retained long pulse; no
short chatter pair becomes a trial. Incomplete unique onset reports remain
available to existing missing-offset analysis, without inventing a complete pulse.

The invalid-handle-0 error came from normal close followed by an exit guard
holding a stale struct copy. The fix in `4bc74a3` supplies shared nested ownership
callbacks, registering each acquired port/file immediately. Cleanup clears
ownership before releasing resources. Handle 0 is valid while owned; repeated
cleanup does nothing, including after an ID is reused by a later connection.
Normal completion, ESC, failed/partial setup, disconnection, and unexpected
errors preserve raw journals and partial MAT/CSV output.
This correction retains that owner and the entire IOPort acquisition source
unchanged; strengthened script tests verify handle 0 and exactly-once closure.

Software exclusions cannot remove automatic TTL pulses already emitted by
the tPAD; external systems may record them. Sensitivity/threshold cause is
suspected but unverified. PO consultation with BBTK and physical sensitivity,
optical/TTL cleanliness, and external recorder qualification remain pending.
Serial commands, TTL configuration, display geometry/RGB, timing schedule,
SkipSyncTests behavior, and the optional calibration source remain unchanged.

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
That fixed-patch change preserved XiD protocol, hardware timestamps, automatic
TTL, matching, trial/cycle schedule, and log writers.

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
The PO subsequently completed the fixed-patch physical run analyzed above.
The PO supplied the two later physical recordings analyzed above. The new
sequence classifier has not been physically tested by the agent.

Final checks on MATLAB R2023b Update 1 passed:

- 11 offline test groups, including 123 two-read split positions, bytewise
  input, malformed/unfinished/overlong messages, original timestamps,
  duplicate/reversed edges, missing/wrong/late optical reports, delayed
  responses/releases across trial boundaries, missing-onset RT handling,
  missing responses, and MAT/CSV exports including scalar early-failure data.
- 10 focused optical regression groups cover normal 500 ms pulses, onset and
  offset chatter, equal-ms P/R/P and R/P/R, multiple-pair bursts, thresholds,
  independently intended close transitions, startup/incomplete/missing/flagged
  events, cross-trial receipt, record preservation/idempotence, valid hardware
  RT anchors, and separate pulse-recovery/missed-deadline results.
- Read-only replay of all three historical raw sessions reproduces every
  original hardware record/timestamp and verifies exact recovery/artifact counts,
  corrected duplicate/state flags, and preserved missed-flip FAILs. New exports are
  under `.local/lab_replay/`; the test explicitly skips if source data is absent.
- 30 simulated script scenarios plus geometry/ownership checks: both acquisition
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
  All serial successes now use handle 0 and reject double closes. Additional
  cases cover setup write failure, acknowledgement timeout, setup ESC, bounce
  in both complete scripts (raw 100/100 -> 50/50 cycles, 20/20 -> 10/10 task),
  zero-ms onset chatter in both scripts, combined onset/offset chatter (150/150
  -> 50/50 cycles), separate unclassified/classified exports, and repeated stale
  cleanup after the port/file IDs have been reused.
- Existing optional-calibration tests still cover mixed key-name cells, window
  movement, primary/secondary desktop coordinates, focus, controls, and saving
  or byte-for-byte preservation on ESC. The calibration source is unchanged.
- MATLAB Code Analyzer: zero findings across all 17 MATLAB source/test files.
  Intentional test-only shared state has explicit analyzer annotations.

The synthetic `input` stub produces an expected built-in-shadowing warning.
Test code restores the prior MATLAB folder/path. Full console output is in
`.local/optical_sequence_checks.log`; final focused RT and zero-finding Analyzer
results after the formatting correction are in `.local/optical_sequence_final_checks.log`.
Test artifacts are ignored by Git. Synthetic test
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
touching `m1_patch.m`: `e092baf`. Initial optical/cleanup hotfix: `4bc74a3`.
The sequence-classification correction is the latest commit touching
`m1_classify_optical.m`: `git log -1 --format=%H -- m1_classify_optical.m`.
M2 implementation commit: `b47b0ea4e1f5df5dcc142824fdd5adedbff88371`.
The original local-only policy is superseded by the publication workflow above.

## Continuing laboratory qualification

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
3. After BBTK sensitivity advice, run `opto_50_cycles` while recording the
   optical TTL output with the existing approved setup. Inspect both raw and
   filtered records; require 50/50 raw and retained, zero ignored pairs, all
   matched in sequence, zero anomalies, and optical result PASS for a clean
   sensor stream. Verify physical TTL has no short extra pulses separately.
   A pulse-recovery PASS alone does not qualify physical output. Inspect
   durations and flips; the recorded first-ON missed deadlines and raw artifacts
   in both recent runs remain qualification issues.
4. Start the external recorders. Run `simple_task`, press/release physical
   Button 1 once to synchronize, and perform ten trials. Confirm the separate
   sync event, optical edges, hardware RTs, missing/premature responses, and
   press/release pairing. Repeat with an ESC abort and inspect partial outputs.
5. With the existing approved wiring, physically verify automatic Button 1 and
   optical onset/offset TTL transitions and their recording in each acquisition
   system. Record measurements/settings and PO qualification of the external TTL path.

M2 is the four-choice task described above. EyeLink API integration remains
deferred to a separately authorized milestone, reusing the tPAD reader.
There is no implementation blocker; physical acceptance needs PO laboratory
access and the existing PTB/hardware setup.
