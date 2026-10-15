# M1 project handoff

Delivery date: 2026-10-15 (Europe/Zurich). Status: software implemented; laboratory
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
path. No software was installed and no real PTB display or serial port was opened.

Final checks on MATLAB R2023b Update 1 passed:

- 11 offline test groups, including 123 two-read split positions, bytewise
  input, malformed/unfinished/overlong messages, original timestamps,
  duplicate/reversed edges, missing/wrong/late optical reports, delayed
  responses/releases across trial boundaries, missing-onset RT handling,
  missing responses, and MAT/CSV exports including scalar early-failure data.
- Nine simulated script scenarios: measured patch calibration; optical
  success; no optical events (expected FAIL); optical ESC with partial data;
  ten-trial success; missing optical onset with unavailable RT; ESC while
  waiting for synchronization release; serial disconnection; and overlapping
  patch rejection. Simulated acquisition scenarios checked cleanup and saves.
- MATLAB Code Analyzer: zero findings across all 14 MATLAB source/test files.
  Intentional test-only shared state has explicit analyzer annotations.

The synthetic `input` stub produces an expected built-in-shadowing warning.
Test code restores the prior MATLAB folder/path. Full console output is in
`.local/final_checks.log`; test artifacts are ignored by Git. Synthetic test
success does not qualify physical timing or trigger delivery.

Known limits: single selected display/sensor/button, frame-quantized durations,
250 ms receipt matching bound, 50 ms optical duration tolerance, no clock drift
or wrap correction, no release beyond the final drain, and no guaranteed recovery
after power loss/forced process termination. Severe latency makes fixation/ITI
context less certain even when hardware RT remains recoverable.

## Local Git

Branch: `main`. The delivered commit is identified by the local tag `m1`;
obtain its exact hash with `git rev-parse m1` (also reported in delivery).
No remote is configured and no push is part of this work.

## Exact next steps for PO acceptance

1. Make the existing Psychtoolbox installation available on the R2023b path;
   check `which Screen` and `which IOPort`. Set the actual COM port in both
   acquisition scripts. Resolve PTB sync failures without disabling checks.
2. Run `opto_calibration`, enter measured active screen dimensions, position
   the 4 cm patch, and adjust sensitivity with the existing BBTK functionality.
   Record the installed firmware, sensitivity, and smoothing settings. Close
   the BBTK app before running an acquisition script.
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
