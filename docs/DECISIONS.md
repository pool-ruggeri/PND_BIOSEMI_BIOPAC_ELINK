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
- Optical matching uses nonoverlapping 250 ms host receipt gates. This deliberately
  rejects late/ambiguous reports instead of shifting assignments after a loss.
  The 50 ms duration tolerance compares elapsed durations, not clock epochs.
  Laboratory evidence may justify changing these two explicit call parameters.
- Task response eligibility uses optical-onset and button hardware times plus
  stream order for equal-ms ties. RT remains unavailable without both anchors.
  Release pairing spans trials. Other presses retain receipt-based context,
  which is less certain under excessive serial latency.
- A completed run describes script execution, not hardware acceptance. Optical
  PASS additionally requires all 100 matched reports, correct totals, no
  anomalies, consistent durations, and no missed scheduled flips.
- PO performs physical acceptance. Manufacturer-documented TTL mappings are
  implemented assumptions pending measurement of installed hardware/settings.

No further PO architectural decision is required to implement this milestone.
