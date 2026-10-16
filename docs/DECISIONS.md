# M1 decisions

- PO scope: local Git only; three independently executable MATLAB scripts;
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
