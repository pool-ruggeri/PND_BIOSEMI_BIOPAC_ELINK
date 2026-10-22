# M1 decisions

- Original M1 PO scope (local-only rule superseded on 2026-10-19): three independently executable MATLAB scripts;
  IOPort, Mode 5, 115200 baud; no installations, firmware changes, cabling
  changes, remote repository, software TTL, or EyeLink control.
- Plain functions and small script-local routines implement acquisition and
  presentation. No classes, configuration framework, or Python dependency.
- COM5 is an editable starting value from the read-only Python reference.
  The installed port remains a laboratory check.
- Serial setup uses acknowledged `X` / `MOD5` commands with documented spacing.
  The hardware clock is never explicitly reset, including after synchronization.
  Existing optical sensitivity and smoothing settings are not altered.
- PO decision (2026-10-16): acquisition uses a fixed 150 x 150 px square in the
  exact bottom-left corner, `[0, winH - 150, 150, winH]`. The shared `m1_patch`
  computes it from the open window size; displays too small to fit are rejected.
  Neither acquisition script reads calibration output. Calibration is an
  unchanged optional BBTK sensitivity utility. Its saved geometry has no effect
  on acquisition. Known COM5 contention is handled without protocol changes or
  terminating BBTK: report the failure, close resources, and avoid stale redraws.
- PO decision (2026-10-16): after a Windows 10 VBL synchronization failure,
  both acquisition scripts set `SkipSyncTests=1` before opening any window and
  restore the prior preference on completion, errors, and aborts. The display
  helper preserves the caller's setting. Both scripts print that visual sync
  tests are disabled and Flip timestamps are not scientifically qualified.
  Independent tPAD timestamps, matching, triggers, trial structure, and logging
  remain unchanged. The working calibration script is unchanged.
- PO hotfix: calibration uses a normal, movable 700 x 500 GUI window with
  normal stacking, leaving the BBTK app usable. It uses a 150 px starting square, mouse drag,
  arrow movement, +/- resize, SPACE toggle, ENTER save, and ESC abort without
  saving. Pixel coordinates/dimensions replace manual screen measurements;
  no physical centimeter size is claimed. Non-text entries in PTB's mixed
  key-name table are normalized before all alias mappings. Controls act only
  while the calibration window has focus; no keyboard suppression or serial
  acquisition is used. Calibration-only shielding/sync preferences are restored.
- Saved `desktop_rect` is window-local geometry plus the current native client
  origin, including window movement. Subtracting the selected monitor's desktop
  origin gives the calibration utility's `rect`, which acquisition ignores.
  Window-local and monitor/window global rectangles are retained for inspection.
  A patch outside the selected display is rejected before writing configuration.
- Binary RX journals and hex messages retain original input, including setup,
  malformed lines, and unfinished fragments. Duplicate events are logged rather
  than dropped. No fabricated timestamps, timer unwrapping, or clock alignment.
- PO sequence-classification correction (2026-10-16), superseding the post-OFF
  filter in `4bc74a3`: classify complete Optical 1 ON/OFF sequences after
  acquisition. An intended pulse uses corresponding ON/OFF receipt gates and
  hardware duration within the existing 50 ms displayed-duration tolerance.
  A 0..3 ms short pair is an artifact only next to an intact intended pulse,
  in its onset or offset gate, with the whole burst within 20 ms of the anchor
  transition. Multiple pairs are supported; independently intended transitions,
  incomplete/startup/unsupported events remain retained. Durations/gaps are
  measured only in original hardware ms; receipt gates are context, not clock
  alignment. No changed serial acquisition, TTL, or presentation schedule.
- Same-ms P/R/P or R/P/R is not a duplicate: an intervening opposite edge
  establishes a new transition on that sensor. Repeated same-level identities
  remain flagged, never removed. Original global identity detection incorrectly
  rejected valid ONs and caused cascading false state errors. Parser bytes,
  order, timestamps, and button records remain preserved.
- Read-only replays: 10:51:38 has 61/61 raw -> 50 intended pulses plus 11
  artifacts (2 onset/9 offset, 0..2 ms); long intervals 502..505 ms. 11:51:33
  has 55/55 raw -> 50 pulses plus 5 artifacts (1 onset/4 offset, 0..3 ms);
  long intervals 502..506 ms. Both have zero missing/unresolved reports and
  pulse recovery PASS. Each retains one missed first-ON flip deadline, so full
  checks FAIL. Earlier 10:11:38 now recovers 50 pulses plus 13 artifacts,
  with full checks PASS. Fixture expectations never drive runtime analysis.
- Raw journals and `run.raw_messages`/`raw_messages.csv` remain distinct from
  classified `run.messages`/event CSVs. `optical_pulses.csv` records complete
  pairs, original hardware duration, and classification. Raw totals include
  startup; validation retains the first-optical-flip through final-drain scope.
  Button synchronization/pairing and RT formula are unchanged. After onset
  chatter, use the actual ON beginning the retained long pulse as the RT anchor.
- Software reconstruction does not clean already emitted tPAD TTL pulses.
  External systems may record the short pulses. No automatic TTL settings or
  serial commands change. Sensitivity/threshold cause is unverified; PO/BBTK
  sensitivity investigation and separate physical optical/TTL qualification
  remain pending.
- Serial cleanup uses one shared resource owner across struct snapshots and
  the exit guard. Valid handle 0 closes once; repeated cleanup cannot close a
  later reused port/file ID. Normal exit, ESC, partial setup and unexpected
  failures retain the same protocol and acquired-data preservation.
- Optical matching uses nonoverlapping 250 ms host receipt gates. This deliberately
  rejects late/ambiguous reports instead of shifting assignments after a loss.
  The 50 ms duration tolerance compares elapsed durations, not clock epochs.
  Laboratory evidence may justify changing these two explicit call parameters.
- Task response eligibility uses optical-onset and button hardware times plus
  stream order for equal-ms ties. RT remains unavailable without both anchors.
  Release pairing spans trials. Other presses retain receipt-based context,
  which is less certain under excessive serial latency.
- A completed run describes script execution, not hardware acceptance. Optical
  `pulse_recovery_result` PASS requires all 50 complete intended pulses, all
  100 unique matched edges, correct totals, no unresolved anomalies, and consistent
  durations. The original `result` also requires no missed scheduled flips.
  A separate raw-artifact warning persists after successful reconstruction.
- PO performs physical acceptance. Manufacturer-documented TTL mappings are
  implemented assumptions pending measurement of installed hardware/settings.

No further PO architectural decision is required to implement this milestone.

## M2 four-choice numbered-circle task (2026-10-16)

- PO scope: add `numbered_circle_task.m`; leave `simple_task.m`,
  `opto_50_cycles.m`, and `opto_calibration.m` intact as the M1 reference.
  Reuse Mode 5 IOPort acquisition, parsing, optical classification, geometry,
  cleanup, logging, and synchronization. No second serial framework or dependencies.
- Ten targets `[1 2 3 4 1 2 3 4 1 2]`; white filled circle and black digit.
  Fixation is 1000 ms, stimulus 500 ms, total response window 1500 ms from
  onset, and ITI 500 ms. Visual durations retain M1's refresh-frame rounding.
  The 150 px bottom-left optical patch is white only during stimulus.
- Fresh physical B1..B4 press events over XiD supply all behavioral input.
  The first eligible press determines accuracy: matching digit is CORRECT,
  another button INCORRECT; both advance. A held button needs a new physical
  press edge. Premature, late, extra, and release events remain in raw logs.
  Keyboard HID is excluded; PC ESC still aborts safely.
- Online parsed serial input controls advancement. Early responses are latched
  immediately without shortening the 500 ms display; later responses start
  ITI when processed. Missing responses wait to the nominal deadline plus
  100 ms bounded serial grace, never another 1500 ms after offset. Polling
  continues throughout; the normal final 500 ms drain is retained.
- `m2_response` shares online/final eligibility. Available hardware anchors
  require latency 0..1500 ms and stream order after optical ON. Without an
  anchor, a receipt-window candidate may advance provisionally; no complete
  ON/OFF pair is required for live response control. Post-deadline first bytes
  without a hardware anchor cannot establish in-window eligibility.
- Final `m2_trials` uses M1's full optical reconstruction. RT is exclusively
  button hardware ms minus retained optical ON hardware ms. Missing/ambiguous
  anchors leave RT NaN and mark the response unverified. Accuracy is observable
  for such serial candidates, but RT means exclude unavailable values. A final
  rejection/change of a provisional online response is flagged, not hidden.
  No direct comparison or synchronization of PTB/tPAD absolute clocks occurs.
- The live response-close boundary limits final candidates. A hardware-valid
  press received in the 100 ms grace may count; hardware RT >1500 ms never
  counts. Reports beyond grace remain auditable but cannot replace the first
  response. Serial latency/ambiguous optics remain qualification limits.
- Button 1 SYNC press/release precedes trials, retains original hardware ms,
  and is excluded from responses. Save `run.sync` and `sync.csv`; do not reset
  the hardware clock. Per-button release pairing spans trial boundaries.
- Keep raw/processed messages and pulse classifications. Trial rows retain
  target/button/outcome, original hardware RT fields, PTB presentation/control
  times, optical artifacts, and missing/ambiguous/premature/late flags.
  Partial aborted windows without responses are INCOMPLETE; unpresented trials
  are NOT_PRESENTED. Responses already acquired before abort remain preserved.
- Retain SkipSyncTests=1 with restoration and warnings. No software TTL, mode,
  wiring, sensitivity, firmware, or EyeLink API changes. Physical qualification
  of B1..B4/optical TTL outputs and recording remains the PO's laboratory work.
- Original M2 delivery used a local `main` commit only; publication was
  authorized on 2026-10-19. M2 reuses the existing simulated
  PTB/IOPort fixture and adds small focused hardware-eligibility tests.

## GitHub publication and reported laboratory acceptance (2026-10-19)

- PO explicitly authorizes private GitHub publication and synchronization;
  the previous prohibition on configuring a remote or pushing is lifted.
  PO selected owner `pool-ruggeri`. The private canonical repository is
  [pool-ruggeri/PND_BIOSEMI_BIOPAC_ELINK](https://github.com/pool-ruggeri/PND_BIOSEMI_BIOPAC_ELINK),
  remote `origin`, with `main` tracking `origin/main` and tag `m1` published.
  Verify authenticated ownership, private visibility, matching refs, and clean
  working tree. Preserve the complete M1/M2 history and existing `m1` tag.
  Do not force-push, rewrite history, or overwrite an unrelated repository.
- GitHub is the canonical repository from this milestone. Accepted changes
  require handoff/decision updates, successful checks, local commit, branch
  push, and verification of remote synchronization. Keep the existing workflow;
  no new branches policy, CI, Actions, or administrative framework is required.
- Publication includes code, tests, documentation, and necessary configuration.
  Participant data, raw laboratory recordings, calibration/workspace MAT files,
  generated caches/output, and credentials remain excluded. Preserve all local
  recordings; publishing experimental data requires separate explicit approval.
- PO-reported physical evidence: M1's 50-cycle optical test recovered 50 valid
  ON/OFF cycles with short artifacts classified. M2's physical ten-trial run
  completed with 9 correct, 1 incorrect, 0 timeouts, an initial SYNC event,
  10 valid optical ON/OFF cycles, and verified hardware RTs. These reported
  laboratory results are distinct from synthetic regression results.
- Remaining qualification: external TTL recording with BioSemi, BIOPAC, and
  EyeLink; full display timing; EyeLink 1000 Plus software integration; and
  the BBTK optical sensitivity investigation. Publication adds no hardware,
  timing, serial, trigger, or integration changes.


## M3 continuous EyeLink integration (2026-10-19)

- TL/PO authorizes the audited M3 design as an independent
  `numbered_circle_eyelink.m`; keep every M1/M2 production file unchanged and
  reuse serial, optical, geometry, response and logging helpers. One small
  EyeLink owner provides separate shared lifecycle/recovery state.
- Correct the audit's EDF claim: `dontOpenExisting` never provided reliable
  protection and newer PTB rejects a nonzero flag. Use OpenFile without it
  only after local history checks, a persisted run/name/destination mapping,
  and explicit operator confirmation that the proposed Host filename is unused.
  Randomness is not a guarantee. No destructive Host collision test, automatic
  overwrite, or Host deletion is permitted. A wrong human confirmation remains
  a risk until a non-destructive Host existence check is separately verified.
- Require real normal connection, reject dummy/broadcast/foreign ownership,
  and log tracker/version data. Read required GAZE file-sample and
  FIXATION/SACCADE/BLINK/MESSAGE file-event availability; disabled or
  unverifiable settings originally stopped for operator/PO action without
  reconfiguration (unusable-reply policy superseded by the 2026-10-20 hotfix below).
  Standard calibration AND validation require explicit operator quality
  acceptance; no numerical thresholds or Host geometry/eye/rate/filter changes
  are invented. Only actual display-pixel coordinates and run preamble are set.
- Start exactly one file-sample/event recording before physical tPAD SYNC,
  after first TRIALID 1. The pretrial SYNC interval is the prestimulus portion
  of Data Viewer Trial 1. Do not introduce an eleventh trial or duplicate first
  boundary. Initial SYNC remains a separate original-timestamp MATLAB event.
- Use manufacturer DISPLAY_COORDS/TRIALID/!V TRIAL_VAR/TRIAL_RESULT syntax and
  custom SESSION_START/TPAD_SYNC/STIMULUS_ONSET/STIMULUS_OFFSET/RESPONSE/SESSION_END
  labels. Clearly name online snapshot variables. Final MATLAB optical-to-button
  hardware RT, accuracy and validity are authoritative; do not retrofit closed
  Data Viewer trials or transform PTB/tPAD/EyeLink clocks. Ethernet MSG is not TTL INPUT.
- Preserve M2's ten targets, timing, four serial buttons, patch, raw records,
  classifier, final RT and serial-controlled advancement. No software TTL.
  Message submission status/duration and explicit poll gaps are logged. Keep
  blocking setup/file commands outside trials; send markers after Flips and
  variable bursts within the fixed ITI. Detected >=250 ms serial interruption
  or an exhausted ITI is an error, not grounds to expand tolerances/windows.
- Save tPAD results before independent, exactly-once EyeLink finalization and
  explicit-destination transfer. Verify positive bytes and exact local size;
  retain partial files and Host originals, refuse existing destinations, and
  preserve recovery metadata even if transfer fails. No reconnect/resume or
  dependency on a still-open display during recovery.
- Offline mocks and regressions can complete software delivery. Real connection,
  calibration, recording, gaze/event EDF contents, Data Viewer ten-trial import,
  abort/transfer recovery and integrated timing remain controlled lab acceptance.
  Full display and external TTL qualification remain separate; do not configure
  EyeLink physical digital INPUT, networking, firmware or installed software.

## M3 status-0 empty-reply preflight hotfix (2026-10-20)

- PO physical test: real Host connection and initialization succeeded on
  EYELINK CL 5.50; status-0 empty/unusable `file_sample_data` reply stopped the
  task before EDF creation. This is reported hardware evidence, separate from
  automated tests. No EDF/gaze/event/timing qualification follows from it.
- A successful ReadFromTracker request status does not guarantee usable reply
  data. Retry only status-0 unusable replies, at most three attempts per setting,
  with 50 ms between attempts in addition to PTB's native timeout. Retain each
  raw reply, status, attempt number and outcome; all checks remain before EDF,
  window and tPAD initialization. Do not modify Host settings or installed SDK.
- Recognizable token lists verify the existing required GAZE and
  FIXATION/SACCADE/BLINK/MESSAGE fields. Readable missing fields, nonzero status
  or native exceptions stop with no override. Empty/nontext/malformed/unknown
  replies leave configuration UNVERIFIED, rather than declaring it invalid.
- If retries are exhausted and neither query identified a configuration error,
  require the operator to check Host recording settings and explicitly type
  `HOST CHECKED NONPARTICIPANT`. Only a controlled nonparticipant EDF diagnostic
  may continue; refusal cancels before creation. The unused-EDF name confirmation
  and all calibration/recording safeguards still apply independently.
- Keep UNVERIFIED, Host-check confirmation, nonparticipant diagnostic and
  required EDF validation in run/recovery metadata. A completed diagnostic or
  byte-verified transfer never upgrades this status. Post-recording EDF/EDF2ASC
  validation must establish actual gaze samples and required events before
  qualification. Preserve M1/M2, calibration, serial acquisition, hardware
  timestamps, TTL, patch, SkipSyncTests and ten-trial logic.

## M3/M4 PO-supplied physical qualification evidence (2026-10-20)

- Record the PO's physical laboratory results separately from automated tests.
  M3 completed a successful **10-trial EyeLink session**, with EDF creation and
  verified transfer, real gaze samples and all required trial markers.
- M4: **`E9B2C08B.edf` converted successfully**, with **413 events,
  23,670 samples and one recording block**. Physical EyeLink INPUT evidence was
  observed for Optical 1 and B1-B4. All **10 optical ON/OFF pairs**, all
  **10 response press/release pairs**, plus the initial **SYNC press/release
  pair** were observed.
- Record the installed-path INPUT mapping below. Hex values are event bit masks;
  EyeLink button labels and tPAD connector pin/output numbers are separate.

| Event | EyeLink INPUT bit mask | EyeLink button |
| --- | --- | --- |
| Optical 1 (Opto) | `0x04` | 3 |
| B1 | `0x20` | 6 |
| B2 | `0x40` | 7 |
| B3 | `0x08` | 4 |
| B4 | `0x10` | 5 |

- Observed idle register: **`0x80`**. Hardware RT comparison: **8/10 exact
  matches**, the other **2 within 1 ms**; reported mean **221.2 ms**.
- This updates the earlier pending status for observed EyeLink recording,
  real EDF contents, INPUT receipt and RT agreement. Qualification is scoped to
  this reported session/path. **Gaze quality, Data Viewer acceptance, display
  synchronization, electrical fan-out and long-duration stability remain
  unqualified.** BioSemi/BIOPAC receipt and BBTK sensitivity work remain separate.
- The implementation agent did not repeat physical tests or EDF conversion.
  Existing synthetic regression/Code Analyzer results remain distinct; no MATLAB
  tests/Analyzer are rerun for this documentation-only change. Preserve all raw
  recordings locally and keep EDF/ASC, tPAD logs and other experimental data
  excluded from Git. Change only README, handoff and decisions; no MATLAB source
  or hardware-setting changes.

## M5 four blocks and fresh EyeLink setup

- Add `numbered_circle_eyelink_4blocks.m` with four copies of M3's ten-trial
  target sequence, timing, grace, patch and physical SYNC. Extract one shared
  controller so the original one-block command stays independently runnable
  without a second acquisition implementation. Existing M1/M2 helpers stay intact.
- Keep one connection/EDF lifecycle and four explicit recording segment states.
  Stop and checkpoint each block before the next fresh calibration/validation.
  Preserve read-only filter checks, unused-name confirmation, file ownership,
  exactly-once partial-start cleanup and conservative transfer/recovery.
- A fresh standard SDK setup and Y quality gate are mandatory per block.
  Require the operator to confirm BOTH a newly performed calibration and newly
  performed validation. Store four separate records with OPERATOR_CONFIRMED and
  machine_verified=false; a last setup/result code cannot certify both. Rejecting
  or cancelling ends the run before the next recording.
- Keep the patch black during setup/breaks with a temporary calibration-only
  pre-swap mask; delegate standard SDK drawing and keyboard and poll the existing
  reader through a thin callback. Remove the mask before trials. No Host
  geometry, filter/rate, clock, SDK, serial or TTL changes are authorized.
- Exactly 40 global TRIALIDs, each block's first ID before recording, and four
  separate B1 press/release SYNCs in those first-trial prestimulus intervals.
  Add block/local/global variables and BLOCK_START/END/TPAD_SYNC markers, with
  whole-session SESSION_START/END. Keep physical INPUT independent from MSG.
- Match optics within original block receipt contexts, retain raw data and all
  timestamps, exclude calibration/break presses from responses and preserve
  global release pairing. Export global/local IDs, per-block/overall summaries,
  calibration and segment recovery state in one session folder. Partial and
  unpresented blocks stay explicit; transfer failure cannot become COMPLETE.
- M5 automated tests and Code Analyzer provide software evidence only. The PO
  must qualify the four-calibration/four-segment EDF/ASC, 40 Data Viewer trials,
  four SYNCs, INPUT/MSG, RTs, calibration-target/sensor behavior and recovery on
  physical hardware. M3/M4 evidence does not establish physical M5 acceptance.
- Software validation: 20 focused M5 scenarios passed, existing M1/M2/M3
  regressions and three historical recovery replays passed, and Code Analyzer
  reported zero findings across 30 MATLAB files. Preserve known missed-flip
  failures in historical full checks. Test evidence is recorded in the handoff;
  no physical M5 acquisition or installed SDK/hardware changes were performed.
