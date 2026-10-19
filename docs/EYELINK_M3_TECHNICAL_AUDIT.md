# M3 EyeLink 1000 Plus technical audit

Audit date: 2026-10-19, Europe/Zurich. PO: user; TL: ChatGPT;
implementation/audit: Codex. **Audit only; M3 is not implemented or authorized
for implementation by this document.**

Repository: [pool-ruggeri/PND_BIOSEMI_BIOPAC_ELINK](https://github.com/pool-ruggeri/PND_BIOSEMI_BIOPAC_ELINK)
(private). Audited baseline: `59da7a921314b8ffb634a0539915e8a1ca5b1875`.
Local and GitHub `main` matched before this audit; the M2 implementation is
`b47b0ea`. No production MATLAB file was changed.

## A. Executive technical verdict

**READY WITH CONSTRAINTS for a subsequent, TL-approved implementation. Not
qualified for participant acquisition or successful hardware integration.**

The installed EyeLink MEX loads in MATLAB R2023b Update 1 and reports the
installed Developer's Kit library version. Its architecture matches MATLAB.
The manufacturer examples demonstrate the required continuous recording and
Data Viewer trial segmentation. There is no evidenced need to replace the
SDK or Psychtoolbox to begin implementation.

The constraints are concrete:

1. A fresh audit MATLAB process did not initially resolve PTB. Loading the
   existing saved user path resolved the MATLAB files; calling the installed
   `PsychStartup` then resolved the `Screen` DLL-loading failure. Both changes
   were confined to that process. M3 needs a path/load preflight, not an
   automatic installer or persistent configuration repair.
2. The configured EyeLink Ethernet adapter is disconnected. Host connection,
   firmware, calibration/validation, recording, EDF creation/transfer, and
   actual Data Viewer import are **NOT TESTED**.
3. Host sample/event filters, sampling rate, eye selection, calibration scheme,
   and validation acceptance limits are not known. Read/confirm them during a
   controlled hardware test; do not copy the demos' configuration commands
   wholesale or silently change those settings.
4. The first Data Viewer trial must encompass the pretrial SYNC interval if
   the MRI example's method is used to prevent an extra initial trial. This
   proposed scope must be accepted by the TL.
5. Final M2 hardware RTs are calculated after acquisition. Live Data Viewer
   trial variables can only be explicitly identified snapshots. Section F
   specifies the proposed distinction; final RTs must never be presented as
   already final during an open trial. TL approval of this reporting policy
   is required before coding it.

No actual tracker initialization, calibration, recording, Host file operation,
participant session, or network/Host configuration change was performed.

## B. Installed software and compatibility inventory

These are observed versions, not a claim that they are the latest releases.

| Component | Actual installation/evidence | Result |
| --- | --- | --- |
| Windows | Registry: Windows 10 Education, 22H2, build 19045.6456 | Matches requested Windows family |
| MATLAB | `C:\Program Files\MATLAB\R2023b\bin\matlab.exe`; `version` = `23.2.0.2380103 (R2023b) Update 1`; `computer('arch')` = `win64`, `mexext` = `mexw64` | Executed successfully; R2018a is also installed, but was not used |
| PTB | `C:\Users\pruggeri\Documents\toolbox\Psychtoolbox`; `PsychtoolboxVersion` = 3.0.19 beta, SVN revision 14005 | Metadata query passed |
| EyeLink Developer's Kit | Windows uninstall registration: `EyeLink Developer's Kit 2.1.762.0`; root `C:\Program Files (x86)\SR Research\EyeLink` | Registered version confirmed by loaded library |
| EyeLink MEX | PTB `PsychBasic\MatlabWindowsFilesR2007a\Eyelink.mexw64`; `Eyelink('Version')` = `3.0.19.656959774`, built 2023-06-08 | Loaded under R2023b; metadata and API help executed |
| SDK core, 64 bit | SDK `libs\x64\eyelink_core64.dll`, file version `2,1,762,0`; `Eyelink('EDKVersion')` also returns `2,1,762,0` | x64 PE machine `0x8664`; runtime load verified |
| SDK core, 32 bit | SDK `libs\eyelink_core.dll`, x86 PE machine `0x14c` | Present; unsuitable for this 64-bit MATLAB process, but not the DLL imported by this MEX |
| SDK graphics/COM | SDK `libs\x64\eyelink_core_graphics64.dll`, `eyelink_core_graphics_sdl2x64.dll`, `SREyeLink64.dll`: file versions `2,1,762,0` | Present; MATLAB callback operation was not exercised; no COM integration is proposed |
| EDF access | SDK `libs\x64\edfapi64.dll`, version `4,2,762,0`; x86 `libs\edfapi.dll` also present | x64 converter imports `edfapi64.dll`; distinct component version is not a mismatch |
| EDF2ASC | SDK `bin\64\edf2asc64.exe`; banner `EDF2ASC version 4.2.762.0 Windows standalone Jul 20 2023` | Version/banner invocation passed without an EDF input; no EDF conversion tested |
| Other EDF utilities | SDK `bin\edf2asc.exe`, `getfile.exe`, `edf_reparser.exe`, `edf_reparser.dll`; `bin\64\srversion64.exe` | Present; retrieval/reparsing utilities were not run |
| Data Viewer | `C:\Program Files\SR Research\DataViewer`; Windows registration `EyeLink DataViewer 64bit 4.3.210` | Installed manual inspected; application/license/import not tested |
| GStreamer | Registry 1.22.5; `C:\gstreamer\1.0\msvc_x86_64\bin`; root environment variable already set | Existing `PsychStartup` makes required DLLs visible in the MATLAB process |
| Screen | PTB Windows MEX, `3.0.19.669150966`, built 2023-10-25 | Version query passed after `PsychStartup`; no display opened |
| IOPort | PTB Windows MEX, `3.0.19.646043753`, built 2023-02-06 | Version query passed; no serial port opened |

### Dependencies and path resolution

The EyeLink MEX import table includes `eyelink_core64.dll`, MATLAB `libmx.dll`
and `libmex.dll`, `VCRUNTIME140.dll`, Windows multimedia/system libraries, and
Universal CRT API sets. The core DLL imports `MSVCR90.dll` and Winsock/system
libraries. The SDK x64 directory contains `msvcr90.dll` version
`9.00.30729.4940`; Windows has `vcruntime140.dll` and `msvcp140.dll` version
`14.42.34438.0`. Successful MEX loading is stronger evidence than file presence
for the dependencies actually loaded. Delayed or setup-only dependencies
remain outside that evidence.

The inherited process PATH includes the SDK `libs`, `libs\x64`, `bin\64`, and
`bin`. The x86 directory being present does not substitute an x86 DLL for
`eyelink_core64.dll`, which has a different name. Do not copy SDK DLLs into the
experiment, MATLAB, or Windows directories.

Fresh audit process, isolated preferences under `.local/eyelink_audit/prefs`:

- Baseline `which ... -all` found neither `Screen`, `IOPort`, `Eyelink`, their
  helpers, nor either prioritized demo. It found two `pathdef.m` files:
  `C:\Users\pruggeri\Documents\MATLAB\pathdef.m` first, and
  `C:\Program Files\MATLAB\R2023b\toolbox\local\pathdef.m` second. No `startup.m`
  resolved. This describes a new audit process, not the path inside an already
  running laboratory GUI MATLAB session.
- Session-only `path(pathdef)` loaded the existing saved user path. Subsequent
  `which ... -all` put the Windows `Screen`, `IOPort`, and `Eyelink` MEX files
  first, followed by their normal `.m` help/fallback files. All EyeLink helper
  and demo resolutions listed in section C pointed to the lab PTB tree.
- Before PTB startup, `Screen('Version')` failed with the Windows missing-module
  error. Its import table includes `glib-2.0-0.dll`. The existing GStreamer bin
  directory was absent from process PATH. Calling `PsychStartup` added it and
  the same Screen MEX then loaded successfully. This is an observed startup
  dependency, not evidence of a missing GStreamer installation.
- A first, limited temporary path probe put `Screen.m` ahead of its MEX; it did
  not call Screen. That audit-created ordering was discarded. The saved-path
  results above establish the correct ordering; do not treat the temporary
  probe as an installed shadow conflict.

The SDK also bundles a separate PTB EyeLink tree under:

`C:\Program Files (x86)\SR Research\EyeLink\SampleExperiments\MATLAB Psychtoolbox\Psychtoolbox`

It is not on the tested saved MATLAB path. The two EyeLink MEX copies have
identical SHA-256:
`bad65249863ea0a9e2f513eacc9da38a6ec36d58ed4a40663ddb0b4c7fba9bb6`.
`EyelinkInitDefaults.m`, `PsychEyelinkDispatchCallback.m`, and the MRI demo
also match byte for byte. SimplePicture differs only in introductory comment
whitespace. No active conflicting EyeLink implementation was found in the
tested resolution. Do not add both trees recursively or execute
`SetupSREyelinkToolbox.m`: inspection shows that it backs up/replaces files
inside the installed PTB tree.

The saved path contains 259 `.svn` entries. They are unnecessary path clutter,
but no resulting EyeLink shadow conflict was observed. This audit does not
rewrite that file. The least disruptive readiness correction is normal
session-local PTB path/startup setup and a MEX-first `which -all` check; no
package replacement or persistent path edit is justified by these results.

The SDK/examples date from 2023 and the installed 1000 Plus manual from 2021.
Their age alone does not establish incompatibility. Current public manufacturer
guidance still recommends the `SR-ResearchDemos` examples. No complete current
SDK/Host-firmware support matrix or latest SDK release was established; this
report does not certify current-release support or prescribe an update.
[Manufacturer PTB guidance](https://www.sr-research.com/support/thread-49.html).

## C. Official files and documentation actually inspected

The following roots are exact paths used below, not hypothetical layouts:

- **P** = `C:\Users\pruggeri\Documents\toolbox\Psychtoolbox`
- **E** = `C:\Program Files (x86)\SR Research\EyeLink`
- **B** = `P\PsychHardware\EyelinkToolbox\EyelinkBasic`
- **D** = `P\PsychHardware\EyelinkToolbox\EyelinkDemos\SR-ResearchDemos`

| ID | Exact file, with roots expanded as defined above | Relevant references |
| --- | --- | --- |
| S1 | `C:\Users\pruggeri\Documents\toolbox\Psychtoolbox\PsychHardware\EyelinkToolbox\EyelinkDemos\SR-ResearchDemos\SimplePicture\EyeLink_SimplePicture.m` | Initialization/EDF lines 27-82; filters 85-99; defaults/calibration/coordinates 113-154; recording 205-213; flips/messages/health 215-278; variables/stop 280-295; closure/transfer/cleanup 302-367 |
| S2 | `C:\Users\pruggeri\Documents\toolbox\Psychtoolbox\PsychHardware\EyelinkToolbox\EyelinkDemos\SR-ResearchDemos\MRI_BlockRecord\EyeLink_MRI_BlockRecord.m` | Setup 37-172; first TRIALID/start before trigger 195-218; subsequent trial boundaries 245-253; trigger/onset 261-289; health 297-337; variables/results 347-355; block stop 363-366; closure/recovery/transfer 370-430 |
| S3 | SDK copies of S1/S2 under `E\SampleExperiments\MATLAB Psychtoolbox\Psychtoolbox\PsychHardware\EyelinkToolbox\EyelinkDemos\SR-ResearchDemos` | Both compared with lab copies; S1 has only comment whitespace differences, S2 is identical |
| H1 | `P\PsychHardware\EyelinkToolbox\EyelinkOneLiners\EyelinkInit.m` | Result/dummy contract, callback argument, real initialization, interactive fallback to dummy |
| H2 | `B\EyelinkInitDefaults.m`, `B\EyelinkUpdateDefaults.m` | Defaults, window-coordinate command, callback registration; UpdateDefaults passes el to callback and can load image targets |
| H3 | `B\EyelinkDoTrackerSetup.m`, `B\EyelinkDoDriftCorrection.m` | Setup wraps `StartSetup`; drift loops may return to setup; successful return is not a measured validation-quality threshold |
| H4 | `B\PsychEyelinkDispatchCallback.m` | Setup/camera/key/target callbacks; lines 176-317 dispatch; 371 flip; 379-516 drawing; 522-572 beeps/Snd |
| H5 | `P\PsychInitialize\PsychStartup.m` | Lines 35-149: process-local Windows DLL path setup, including GStreamer |
| M1 | `E\SampleExperiments\MATLAB Psychtoolbox\EyelinkToolbox-Documentation.html` | API sections OpenFile, CloseFile, ReceiveFile, StartRecording, CheckRecording, Command, Message, EDKVersion, StartSetup, CalMessage; no Host operations executed |
| M2 | `E\Docs\EyeLink Programmers Guide.pdf` (443 PDF pages; generated May 2023) | Sections 24.4 file lifecycle, 24.7 file data; 25.6.3.9 naming/open, 25.6.3.10 transfer; PDF pages 177, 182, 236-241 inspected, plus relevant API examples |
| M3 | `E\Docs\UserManuals\EyeLink 1000 Plus User Manual.pdf` (154 PDF pages; title version 1.0.17) | Host/network context, PDF pages 22-31 searched; pages 30-31 inspected for documented Display/Host network pair |
| M4 | `C:\Program Files\SR Research\DataViewer\manual\DataViewer.pdf` (332 PDF pages; 4.3-era manual, January 2023) | Section 5.1.1.4 printed p.26 / PDF p.34 continuous trial splitting; 8.1 printed pp.168-169 / PDF pp.176-177; 8.2.2 printed p.170 / PDF p.178 coordinates; 8.3.2 printed p.172 / PDF p.180 single-variable syntax |
| M5 | `E\EDF_Access_API\Readme.txt`, `E\EDF_Access_API\CExample\main.c` | Library architecture layout; converter options in `print_usage`, lines 834 onward. The readme has a stale x64 library-name label; actual installed DLL is `edfapi64.dll` |

The Programmer's Guide `.chm`, `EyeLinkCOM.chm`, EDF Access C API PDF, and
other tracker manuals are present. They were inventoried, not treated as
additional fully reviewed sources. The COM, C-build, video, stereo, and gaze
contingent frameworks are unnecessary for this passive recording extension.

Public primary sources checked on the audit date:

- [Manufacturer Psychtoolbox guidance](https://www.sr-research.com/support/thread-49.html)
  recommends SR-ResearchDemos and calibration sound initialization.
- [Manufacturer Data Viewer integration protocol](https://www.sr-research.com/support/thread-83.html)
  and [Data Viewer message FAQ](https://www.sr-research.com/support/thread-168-post-168.html)
  corroborate trial boundaries and within-trial variables.
- [PTB EyeLink API](https://psychtoolbox.org/docs/Eyelink),
  [OpenFile](https://psychtoolbox.org/docs/Eyelink-OpenFile),
  [ReceiveFile](https://psychtoolbox.org/docs/Eyelink-ReceiveFile),
  [Command](https://psychtoolbox.org/docs/Eyelink-Command),
  [Message](https://psychtoolbox.org/docs/Eyelink-Message), and
  [CheckRecording](https://psychtoolbox.org/docs/Eyelink-CheckRecording)
  were cross-checked against installed MEX help. Installed help governs this
  machine where a newer online implementation might differ.

No proprietary manual, vendor source, SDK binary, or experimental recording is
copied into this deliverable. References above identify the originals.

## D. Verified MATLAB API capabilities and their limits

All native APIs below are supplied by
`P\PsychBasic\MatlabWindowsFilesR2007a\Eyelink.mexw64`. Presence and help
queries do not establish successful Host execution.

| Operation/API | Contract evidenced locally | Official example / status |
| --- | --- | --- |
| `EyelinkInit(0)` [H1] | Returns success flag 1/0 and actual dummy flag; can offer dummy mode if real initialization fails | S1 29-40; S2 39-45. Not called. M3 must inspect both outputs and require `IsConnected == 1`, rejecting dummy/broadcast acquisition |
| `Eyelink('Initialize', callback)` | 0 success, -1 error; can register `PsychEyelinkDispatchCallback` directly | H1 implements this. Not called; direct initialization is an alternative if avoiding the helper's dummy prompt is approved |
| `Eyelink('SetAddress', address)` | API present; set before initialization for a non-default address | S1 32-34. Default documented Host address still needs physical confirmation; not called |
| `Eyelink('IsConnected')` | 1 normal connection, 0 disconnected, -1 dummy, 2 broadcast | Installed help executed; connection query itself not used as a hardware test |
| `Eyelink('OpenFile', name, 1)` | 0 success, otherwise error; optional nonzero `dontOpenExisting` refuses an existing file and may raise an error. Default flag is 0 | S1 59-64 / S2 66-72 show status checking but omit overwrite protection. The installed MEX help explicitly supports the protective flag |
| `EyelinkInitDefaults(window)`, `EyelinkUpdateDefaults(el)` [H2] | Create/pass graphics defaults and callback state; InitDefaults may send screen coordinates when connected | S1 115-143; S2 125-143. Files resolve; not executed with a real window |
| `EyelinkDoTrackerSetup(el)` [H3] | Interactive setup wraps native `StartSetup`, returns its result; calibration and validation are operator-controlled | S1 152-154; S2 170-172. Not run; returning from setup alone does not certify validation quality |
| `EyelinkDoDriftCorrection(el, x, y)` [H3] | Helper initially assumes success; returns 0 on disconnection/termination; ESC may loop back to setup | S1 201-203; S2 195-197. Not run; 1000 Plus defaults to a drift check according to the example, not a promise of applied correction |
| `Eyelink('CalMessage')` | Returns result and text associated with last calibration/validation/drift result | M1 API documentation inspected; result interpretation and acceptable error limits need controlled validation |
| `Eyelink('StartRecording', 1, 1, 0, 0)` | Requests file samples and events, with no online sample/event stream requested; start error must be checked, 0 required | S1 211-213; S2 209-211 demonstrate start and 100 ms preroll using defaults. Explicit file-only flags are the proposed M3 choice, not a tested Host operation |
| `Eyelink('CheckRecording')` | 0 means in progress; nonzero indicates abort/error/disconnection. Abort handling can invoke Host abort behavior | S1 235-247; S2 297-337. Help executed, actual recording not tested |
| `Eyelink('Message', '%s', text)` | Returns send-error status. Native formatting documents character/integer arguments only | S1 223-225, 286-294; S2 272-283, 347-354. Preformat fractional PTB values with MATLAB `sprintf` into `text`; do not pass `%f` directly to the native formatter |
| `Eyelink('Command', ...)` | Returns command result; allows up to 500 ms for completion | S1 89-98, 140-147; S2 97-106. Setup/cleanup only in proposed design |
| `Eyelink('SetOfflineMode')` | Waits for the mode transition | S1 308; S2 376. Keep outside timed presentation/polling intervals |
| `Eyelink('StopRecording')` | Stops eye recording; this call has no documented success output in installed MATLAB help | S1 280-282; S2 363-366. Track ownership and preserve failure/unknown state |
| `Eyelink('CloseFile')` | 0 success, otherwise error | S1 311; S2 379. Successful close precedes transfer |
| `Eyelink('ReceiveFile', hostName, destination, 0)` | Positive return is bytes transferred; 0 is cancellation; negative is error | S1 333-364; S2 401-428. Use explicit source/destination, not last-file/pwd defaults; not executed |
| `Eyelink('Shutdown')` | Releases the EyeLink connection | S1 325; S2 393. Only after preserving/recovering this run's EDF; no call made during audit |

Eye movement samples/events can be written by the Host to EDF without fetching
each gaze sample in MATLAB. M3 has no gaze-contingent requirement, so a live
gaze buffer/reader would add unnecessary acquisition work. Actual sample and
event contents still depend on the installed Host configuration; see E.

## E. Recommended lifecycle and continuous recording

This is a proposed implementation specification, pending TL approval.

1. Create the normal unique local run folder using `m1_log('new', ...)` under
   `data/`, with the new script name. Establish independent shared EyeLink
   ownership state and an exit guard immediately. Refuse to take over an
   existing connection/file that this run does not own.
2. Verify MEX-first path resolution and load metadata before acquisition.
   Initialize the real connection with callbacks, check success/dummy outputs
   and `IsConnected == 1`. Record actual SDK/MEX/Host versions; no silent dummy
   fallback in the acquisition executable.
3. Choose/persist the Host filename and local destination mapping, then open
   using `OpenFile(..., 1)`. Require success before marking file ownership.
   Add a short run-ID preamble immediately after opening.
4. Open the same full-screen display using `m1_display`, `SkipSyncTests=1`,
   unchanged bottom-left `m1_patch` geometry/RGB, and existing restoration
   guards. Setup may open the display before connection instead if callback
   initialization requires it; no recording begins in either ordering yet.
5. Configure the callback with this window and an appropriate black background,
   visible white target/text, and the existing default target type. Initialize
   calibration sound per the official demos before setup. Do not require demo
   JPEG/video files or introduce a media subsystem. Audio/camera/target drawing
   must be physically tested; metadata loading did not exercise them.
6. Set `screen_pixel_coords = 0 0 W-1 H-1` using actual full-screen dimensions;
   send `DISPLAY_COORDS 0 0 W-1 H-1` before the first `TRIALID`. PTB rectangles
   use an exclusive right/bottom boundary, while these coordinates identify
   the last pixel. Keep the optical rectangle `[0 H-150 150 H]` unchanged.
7. Inspect/confirm current Host sample/event settings offline. Required EDF
   contents are gaze samples and messages plus the required fixation, saccade,
   and blink events for the configured eye(s). Do not force LEFT/RIGHT, sample
   rate, `HTARGET`, link filters, parser thresholds, INPUT settings, HV9,
   calibration-area changes, button remapping, or online drift correction
   simply because a demo does so. If needed data are disabled, report the exact
   setting and obtain PO approval before changing it. A successful `ReadFromTracker`
   request alone must not be assumed to support every possible variable name.
8. Perform operator setup, calibration, and validation. Record the last
   calibration/validation result text and operator acceptance. Acceptance
   limits/calibration scheme need the TL/PO's protocol; do not invent them.
   If a pre-session drift check is included, do it here, before recording.
   No recalibration/drift check between trials in this continuous-recording run.
9. Restore the experimental black frame after callbacks. Open tPAD with the
   unchanged `tpad_io` handshake, shared ownership, and settling/polling. This
   keeps interactive calibration out of active serial journaling. Calibration
   may itself stimulate the optical sensor and automatic TTL; it is outside
   the experimental interval. Arrange external-recorder readiness after setup,
   and do not count calibration flashes as experimental optical events.
10. Offline, send the first `TRIALID 1`, then start a **single** recording with
    file samples/events enabled. Check the return, allow at least the demo's
    100 ms preroll while continuing tPAD polling, and require successful
    `CheckRecording` before showing/accepting the initial synchronization cue.
    Send `SESSION_START` after recording is confirmed.
11. Present the existing tPAD SYNC screen; detect/retain physical Button 1
    press/release exactly as M2. Send `TPAD_SYNC` when the press is parsed,
    carrying its original tPAD ms and sequence. The EyeLink recording is
    already running. Do not reset either clock.
12. Execute the ten M2 trials unchanged: target order, four-button eligibility,
    fixation, stimulus, response/grace rules, ITI, black/white patch transitions,
    and raw serial acquisition. For trials 2-10 send `TRIALID n` before their
    fixation. Send custom onset/offset/response markers and within-trial
    variables using F and H. Recording is never stopped between trials.
13. Complete the normal black cleanup, 500 ms serial drain, parser finish,
    optical classification, and `m2_trials` analysis, preserving raw/classified
    records separately. Save the normal MATLAB outputs and recovery state
    before a potentially slow EDF transfer. Serial resources are closed exactly
    once using existing ownership; EyeLink recovery must not depend on them.
14. Send available final-analysis annotations and `SESSION_END` if connected.
    Allow approximately 100 ms eye-recording tail after the last annotation,
    then stop once, enter offline mode, close the owned EDF and check its
    status, transfer a copy, verify it, then shut down the owned connection.
    These steps occur after timed trials/serial completion, not inside them.
    Persist all lifecycle/transfer outcomes in the local run record.

### Why continuous recording works with Data Viewer

S2 starts recording before waiting for the scanner trigger, keeps recording
through three trials per block, and sends `TRIALID`/`TRIAL_RESULT` between
trials without stopping. Its first `TRIALID` is deliberately before
`StartRecording` to avoid an extra initial Data Viewer trial. M3 can use one
such block for SYNC and all ten trials. Data Viewer M4 section 5.1.1.4 explicitly
supports splitting a continuous recording with these messages.

**Proposed scope:** first `TRIALID 1` before recording, so the SYNC waiting
period is the pre-stimulus part of Data Viewer trial 1; it is not an eleventh
behavioral trial. Stimulus-specific analyses use `STIMULUS_ONSET` and
`STIMULUS_OFFSET`, rather than assuming Data Viewer trial zero equals stimulus
onset. Do not send a second `TRIALID 1` after SYNC. The MATLAB `run.sync` and
trial records retain their existing separation. This first-trial scope is an
explicit TL review point. An alternative separate SYNC Data Viewer segment
would produce an extra analysis segment and needs a different approved spec.

`SESSION_END` and later recovery information outside a closed trial remain
EDF messages, but may not appear inside Data Viewer's parsed trial views.

## F. Proposed Data Viewer and custom event protocol

The labels in the custom rows below have no built-in trial parsing semantics.
Ethernet messages are annotations, not physical INPUT events. No leading
numeric time-offset prefix will be used, because no clock transformation has
been qualified.

| Message syntax | Type and placement |
| --- | --- |
| `DISPLAY_COORDS 0 0 <W-1> <H-1>` | Manufacturer-defined pretrial command; after EDF creation and before first TRIALID |
| `SESSION_START run_id=<id>` | Custom; after start is verified and before initial tPAD SYNC |
| `TPAD_SYNC tpad_ms=<integer> sequence=<integer>` | Custom; once for the accepted initial Button 1 press, after parsing it; preserve the release separately in MATLAB |
| `TRIALID <n>` | Manufacturer-defined trial start; first before StartRecording, subsequent ones before the respective fixation |
| `STIMULUS_ONSET trial=<n> flip_ptb=<seconds>` | Custom; immediately after the actual onset Flip returns; PTB value is descriptive payload, not EyeLink time |
| `STIMULUS_OFFSET trial=<n> flip_ptb=<seconds>` | Custom; immediately after the actual offset Flip returns |
| `RESPONSE trial=<n> button=<b> tpad_ms=<integer> sequence=<integer> stage=ONLINE` | Custom; when a fresh online candidate is selected; never reinterpret it as final scoring or as the physical button timestamp in the EyeLink clock |
| `!V TRIAL_VAR <name> <value>` | Manufacturer-defined variable; after that trial's TRIALID and before its TRIAL_RESULT; one label/value per message |
| `TRIAL_RESULT 0` | Manufacturer-defined end for a normally completed trial; 0 does not mean the answer was correct |
| `TRIAL_RESULT 3` / `TRIAL_RESULT -1` | Proposed abort/error result for the one currently open trial, if still connected; no results for unpresented trials. Accuracy is stored separately |
| `SESSION_END status=<COMPLETE/ABORTED/ERROR>` | Custom; after trials/final annotations, before final recording tail and stop |

Values must be single tokens (underscore instead of internal spaces). Proposed
variables are `trial_number`, `displayed_digit`, `expected_button`,
`actual_button_snapshot`, `correct_snapshot`, `outcome_snapshot`,
`hardware_rt_ms_snapshot`, `response_validity_snapshot`, and
`analysis_stage=ONLINE_SNAPSHOT`. Correctness is 1 for a correct response, 0 for
an incorrect response, and `NA` if no scored response is available. Missing or
ambiguous hardware onset gives `NA` RT, never zero or a PTB substitute.

Snapshot RT uses the same helper rules and units as M2: retained valid optical
ON tPAD ms to selected button-press tPAD ms. The original integer tPAD values
are retained. Use MATLAB `sprintf` to construct a bounded, short character
message, then the native `%s` argument; retain call status and local call times.
Ordinary labels such as `STIMULUS_ONSET` do not automatically create Data Viewer
interest periods or RT definitions; those must be defined in Data Viewer when
needed. An overlay/image/interest-area subsystem is not necessary for trial
parsing and is not proposed for initial M3.

### Final hardware RT versus live variables: a real architectural constraint

`numbered_circle_task.m:110-118` drains/finishes raw acquisition, then classifies
optical sequences and calls `m2_trials`. `listen` uses provisional copies and
can reject a previously selected online response when a hardware anchor arrives.
Therefore a value known during trial n is not guaranteed to equal the final
post-run value. A very delayed or incomplete serial line can make that
difference observable even after an ITI.

Data Viewer ignores `!V TRIAL_VAR` outside its trial's boundaries. Sending
trial n's final RT during trial 10 does not assign it to trial n, and sending it
after every trial has ended does not retroactively update those trials.
Re-emitting TRIALIDs after acquisition would create new wrongly timed trials.
Do neither. [Manufacturer protocol, trial-variable scope](https://www.sr-research.com/support/thread-83.html).

**Recommended minimal policy for TL approval:** send clearly named online
snapshot variables inside each trial; retain authoritative final RT/outcome in
the unchanged MATLAB final analysis. After final analysis, optionally include
one custom `FINAL_TRIAL_DATA trial=<n> ... stage=FINAL` message per presented
trial, with the final helper-derived values, before SESSION_END. These are
delayed summary annotations in the raw EDF, not retrospectively timed events
or native per-trial Data Viewer variables. Never replace the earlier timestamps
or claim that these summaries repair Data Viewer trial variables. The local
final table remains authoritative and any snapshot/final disagreement is
reported. If the TL instead requires final RTs automatically populated into
every native Data Viewer trial-variable row, that requirement needs a separate
approved postprocessing/import or finalization design; it cannot be promised
by the existing live message sequence alone.

This limitation is an audit finding, not a change to M2 or an approved new
analysis feature.

## G. Integration points and unchanged M2 reuse

| Current source location | Proposed M3 integration point |
| --- | --- |
| `numbered_circle_task.m:6-17` | New run name, small EyeLink ownership/status fields and recovery checkpoint; preserve M2 record schema |
| Lines 20-32, display/serial setup | Connection/EDF/defaults/setup before active task; preserve SkipSyncTests restoration and serial-open failure behavior |
| Lines 33-56, SYNC | Recording must already be verified before the SYNC screen; marker derives from stored `run.sync.press_tpad_ms` and sequence, never from a keyboard press |
| Lines 62-72, trial/fixation/onset | First boundary already sent; later TRIALIDs before fixation; custom onset after `flip_record` returns |
| Lines 78-87, offset/response/ITI | Offset marker after flip; candidate marker at online selection; snapshot variables/results within existing 500 ms ITI budget before next TRIALID |
| `listen`, lines 151-183 | Observe changes in `online_response_sequence` for annotations without changing eligibility, deadlines, or candidate rejection; raw events remain untouched |
| Lines 96-119, cleanup/drain/final scoring | Keep black-frame/live-window guards, finish serial first, reuse existing final classifier/trial helper; EyeLink finalization must survive earlier display closure |
| Lines 120-147, outputs | Add EyeLink lifecycle/recovery metadata to the existing run struct; retain standard logs/summary, save before transfer and checkpoint transfer results afterward |

Reusable **unchanged**: `tpad_io`, `tpad_parse`, `m1_wait`, `m1_display`,
`m1_patch`, `m1_classify_optical`, `m1_match_optical`, `m2_response`,
`m2_trials`, `m1_cleanup`, and `m1_log`. `m1_log` already preserves additional
fields of the supplied run struct in `session.mat`. EyeLink cleanup needs its
own owner; the serial owner's nested callbacks must not be replaced.

`numbered_circle_task.m` exposes its controller/draw/flip/listen routines only
as local functions, so it is not an injectable EyeLink host. The minimal new
`numbered_circle_eyelink.m` should retain that small orchestration/drawing code
with explicit EyeLink calls, while calling the shared helpers above. Do not
call M2 and attempt to inject messages around an inaccessible loop, duplicate
the serial reader/classifier, or refactor the validated M2 executable simply to
add hooks. Review the new controller side by side against M2 and test parity.

The four physical buttons, separate initial SYNC, deterministic ten targets,
150 px bottom-left black/white patch, 1000 ms fixation, 500 ms stimulus,
1500 ms hardware RT window, 100 ms serial grace, and 500 ms ITI all remain.
The optional calibration utility remains unchanged.

## H. Timing, synchronization, and blocking risks

| Time/domain | Meaning and permitted use |
| --- | --- |
| PTB `Screen('Flip')` values / `GetSecs` | Display scheduling and host receipt/control times in seconds; original fields remain. SkipSyncTests=1 means visual timing is not scientifically qualified |
| tPAD optical `tpad_ms` | Original integer hardware clock; valid optical ON is the RT anchor after classification |
| tPAD button `tpad_ms` | Same tPAD hardware clock; subtraction from valid optical ON yields hardware RT. Sequence order resolves equal-ms ties |
| EyeLink EDF MSG timestamp | EyeLink clock annotation; send/receipt/queue latency is not a photon or tPAD edge measurement |
| Future EyeLink physical INPUT timestamp | EyeLink-clock physical input event, if wired/configured/recorded and externally qualified; not produced by an Ethernet message |

Embedding `tpad_ms` or `flip_ptb` in a message is data preservation, not a clock
conversion. No offset, drift estimate, tracker-time conversion, timestamp
backdating, or Data Viewer numeric offset prefix belongs in this milestone.

Proposed scheduling rules:

- `Command` can wait up to 500 ms. Configuration commands, status-drawing
  commands, file operations, offline transitions, calibration/drift setup,
  image transfer, and EDF2ASC must stay outside timed trial acquisition.
- Send one short marker immediately after each critical Flip returns, never
  immediately before a scheduled Flip. Poll serial before/after marker calls
  where possible. `Message` has no proven worst-case latency on this PC; its
  send success is not proof of EDF persistence or physical synchrony.
- Poll tPAD first. Keep `m1_wait` unchanged, and do not add an EyeLink call to
  every 1 ms serial polling iteration. No online gaze stream is needed.
- Check recording after start, while waiting for SYNC at a modest cadence,
  before the first fixation, early in each ITI for the next trial, and at
  session end. Finish the ITI check within its existing absolute deadline;
  do not add it after that deadline before the next fixation. Do not put
  `CheckRecording` in the onset-to-offset tight loop:
  its abnormal-state handling may block. Detection during a trial may therefore
  occur at the next boundary; the EDF and run status must expose a loss of
  recording, without automatically repeating/skipping experimental trials.
- Send a small variable/result burst during the existing ITI, interleaving
  serial polls and approximately 1 ms spacing. Use its absolute end deadline;
  do not append waits that lengthen the 500 ms interval. Manufacturer guidance
  warns against excessive message bursts (M4 section 8.3.2). Measure call times
  and poll gaps during qualification, and treat overruns as timing failures.
- Any lengthy call can leave original hardware timestamps intact yet delay
  serial receipts past the existing 250 ms optical matching gates or alter
  response advancement. Do not expand those gates to conceal the problem.
  Avoiding `Command` is necessary but does not prove timing equivalence.
- Keep the existing final serial drain before slow transfer. Cleanup/recovery
  after an EyeLink failure must not block raw serial preservation behind
  network retries. The tPAD's automatic TTL remains independent of MATLAB
  message scheduling, although its physical cleanliness is still unqualified.

The integrated run must measure Flip deadlines, display intervals, response
advancement, EyeLink call duration, and serial-poll gaps. A successful MEX load
does not qualify any of these timing behaviors.

## I. EDF naming, transfer, ownership, and recovery

### Filename and overwrite protection

The local Programmer's Guide 25.6.3.9 specifies a Host EDF basename of at most
eight characters, letters/digits and underscore (underscore only after the
first position), with `.edf` as the extension. Use a stricter safe subset:
`E` followed by seven uppercase hexadecimal characters, e.g. `E12AB34C.edf`.
Generate the suffix per run; do not derive uniqueness solely from the date or
truncate the long MATLAB run ID and assume uniqueness.

Randomness reduces collisions; **`OpenFile(hostName, 1)` provides the
non-overwriting guard**. Persist candidate name, full local run ID, and local
destination in the run's recovery checkpoint before the Host create attempt.
Capture returned errors/exceptions. On an identified existing-name collision,
choose another name with a small bounded retry count; on an unclassified open
failure, abort rather than treating every error as a collision. Never retry
with protection disabled. Do not open/close an unknown existing Host file.
[Installed contract also documented by PTB](https://psychtoolbox.org/docs/Eyelink-OpenFile).

Keep the full MATLAB run ID as the directory name and in session metadata and
EDF preamble/SESSION_START payload; the short EDF name is an alias. An explicit
unique destination inside `run.folder` avoids current-directory surprises.
Check that the local target does not exist; use a fresh recovery filename if
retrying a partial transfer. Preserve partial files as evidence.

### Successful transfer is more than a printed filename

After owned recording stops, require `CloseFile == 0`, then call
`ReceiveFile(hostNameWithExtension, absoluteLocalDestination, 0)`. It is a copy:
do not delete the Host original or reopen it for recovery. A positive return
and an existing local file whose `dir(...).bytes` matches that return are
minimum success checks; 0/cancellation, negatives, or mismatched size remain
failures. Record local SHA-256 for later local integrity checks, without
claiming an independently compared Host checksum.

Use the installed converter only after acquisition on a copy/unique output
directory, preserving the EDF. CExample `print_usage` documents `-p <path>`,
`-c` consistency checking, `-s` samples-only, and `-e` events-only. A later
controlled validation can use `edf2asc64.exe -c -p <fresh_ASC_directory>
<local_EDF>`, capturing exit status and diagnostics. Do not use overwrite `-y`,
repair/disable-consistency `-z`, or message-hiding switches in validation.
Actual conversion of a new EyeLink EDF has not been tested here.

Inspect converted output for one experimental START/END recording block,
nonempty gaze samples with usable values for the configured eye(s), sensible
sample coverage across SYNC/all trials, required eye-event availability,
SESSION_START/TPAD_SYNC/SESSION_END messages, ten ordered TRIALIDs and matching
results on a complete run, and correct variables/abort boundaries. Eye-event
counts depend on behavior; a participant need not blink on every trial. Also
import a controlled test EDF into installed Data Viewer: ten trial containers,
no extra initial trial, correct first-trial preamble interpretation, and
within-trial variables. Binary transfer size alone proves none of this.

### Error and abort requirements

Use a small shared nested EyeLink owner or equivalent mutable state, separate
from serial ownership. Track connection, owned file, recording-start attempt,
recording confirmation, stop/close attempts/results, transfer attempt/bytes,
and errors. Register guards at acquisition time, not only after all setup
succeeds. An ambiguous failed start may require a best-effort stop if this run
owns the connection/file; do not assume a failed return proves the Host never
changed state.

| Exit | Required behavior |
| --- | --- |
| Normal completion | Preserve M2 raw/final logs; finalize owned recording/file; copy/verify EDF; shut down once; restore display/input/SkipSyncTests |
| ESC during SYNC/trials | Keep physical SYNC/partial trials and raw data; close only an actually open Data Viewer trial if possible; mark ABORTED, stop/close/transfer the partial owned EDF |
| Failed initialization/calibration/EDF create | Preserve recovery mapping/status; no trial simulation; release only acquired resources. A file opened before setup failure is still worth closing/transferring |
| COM5 failure | Preserve one primary serial-open error, no invalid-window redraw; EyeLink owner closes/recovers its already opened file without drawing. Do not terminate BBTK |
| EyeLink disconnection or Host abort | Abort the integrated task, preserve tPAD raw data/final drain first; record EyeLink errors, attempt bounded best-effort finalization only when appropriate, and retain Host filename for manual recovery |
| Closed display / MATLAB exception | EyeLink cleanup and explicit-destination ReceiveFile need no Screen call. Independently guard every stop/offline/close/transfer/shutdown step so one failure does not suppress the rest or serial cleanup |
| Hard kill/power loss | Cleanup cannot be guaranteed. A pre-create local checkpoint must identify possible Host EDF; do not overwrite it on restart. Host-side completion/retrieval is a later controlled recovery operation |

Avoid stale onCleanup struct copies and double shutdown/close, as the M1 port
cleanup history already demonstrates. Ownership and recovery status are
separate: clearing a release guard must not erase evidence that closure failed
or remains unknown. Preserve the primary exception and list cleanup failures
separately. Never claim transfer success from the vendor helper's unconditional
destination printout; its status checks are insufficient for this task.

Do not add automatic reconnect/resume, Host file deletion, reparsing, global
CloseAll-style EyeLink takeover, or repeated trials. SDK `getfile.exe`, Host
file-download facilities, or later explicit ReceiveFile can retrieve a known
closed/recoverable file during supervised recovery; none was exercised now.

All EDF/ASC/recovery output belongs under ignored `data/` run directories.
Never stage it, vendor material, participant identifiers, or local audit logs.

## J. Network readiness, unknowns, and controlled laboratory checks

Read-only Windows diagnostics, without changing any setting:

| Interface | Observed state |
| --- | --- |
| `Ethernet`, index 21, Intel(R) Ethernet Connection (7) I219-LM | Configured `100.1.1.2/24`, no default gateway; Disconnected, 0 bps; address state Deprecated while disconnected |
| `Ethernet 3`, index 12, Realtek USB FE Family Controller | Disconnected, 0 bps; link-local `169.254.25.158` |
| `Wi-Fi 2`, index 16, TP-Link Wireless USB Adapter #2 | Up; institutional uplink/default route, not the intended EyeLink direct link |

Expected Host address is **`100.1.1.1`**, based on the manufacturer manual
and matching existing Display-PC interface configuration, not a discovered
live Host setting. `Find-NetRoute -RemoteIPAddress 100.1.1.1` selected the Wi-Fi
default route while Ethernet was disconnected. Consequently no ping or
EyeLink initialization was sent through that unrelated route. Host reachability
and connection are **NOT TESTED**, rather than certified unreachable or an
EyeLink protocol failure. No duplicate IP conflict was demonstrated; an
intended-link routing/readiness problem is evidenced. No firewall, IP, route,
Host, or acquisition configuration was changed.

Later controlled checks, after TL approval and operator readiness:

1. Operator connects/powers the correct Host/direct link. Confirm Ethernet is
   up and the selected route uses that interface before any reachability test.
   Confirm the actual Host IP and absence of an address conflict. If routing
   remains wrong, ask PO before any Windows/Host change.
2. Run metadata/path checks in the actual acquisition MATLAB session. Then
   explicitly authorize a real connection smoke test; `Initialize` can alter
   tracker state, so it was deferred. Confirm Host model/firmware and real mode.
3. Inspect current sampling/eye/filter/INPUT settings, sound/display callbacks,
   calibration and validation quality, and any required approved setting change.
4. Explicitly authorize a nonparticipant EDF test, since OpenFile creates Host
   data and StartRecording changes state. Test protected-name collision refusal,
   recording/health checks, safe abort, stop/close, transfer/retrieval and byte
   checks. No real participant or old Host EDF should be used as a collision test.
5. Validate a controlled ten-trial M3 run against M2 invariants, hardware RTs,
   snapshots/final discrepancies, one continuous recording, and converter/Data
   Viewer checks. Exercise ESC in setup/SYNC/trials, occupied COM5, initial and
   mid-run disconnection, existing destination, canceled transfer, closed display,
   and cleanup errors. Retain all recoverable output.
6. Measure integrated call/poll/Flip timing. Full display qualification and
   external BioSemi/BIOPAC/EyeLink physical TTL INPUT validation remain separate.
   Do not infer clean TTL or common clocks from EDF Ethernet markers.

Outstanding review choices: first-trial SYNC scope, live-versus-final Data Viewer
RT policy, calibration/validation acceptance protocol, and any required Host
filter changes. These are identified proposals/unknowns, not newly approved
project decisions.

## K. Concise M3 implementation plan for TL approval

1. Approve the proposed lifecycle, first-trial preamble scope, snapshot/final
   reporting policy, and calibration protocol. Resolve any requirement for
   final native Data Viewer RT variables before implementation starts.
2. Add `numbered_circle_eyelink.m` as an independent executable, with a small
   local EyeLink owner/message/transfer implementation. Keep M2 and all shared
   serial/optical/response helpers unchanged; no new framework.
3. Implement preflight/real-only initialization, protected short filename and
   recovery checkpoint, defaults/setup/validation, then tPAD open and exactly
   one recording starting before SYNC. Preserve every M2 timing/data invariant.
4. Add the explicit trial/custom protocol, bounded ITI messaging, health checks
   outside scheduled flips, and separate final annotation/analysis handling.
   Record actual call status/time; never transform clocks or replace hardware RT.
5. Add independent exactly-once EyeLink finalization, local-first data safety,
   explicit protected transfer destination, size checks and retained errors.
6. Add focused synthetic regressions for lifecycle ordering, first recording
   before SYNC, ten boundaries/one recording, returned errors/dummy rejection,
   candidate/final differences, filename/transfer collisions, and all cleanup
   paths. Reuse the existing mocked tPAD/PTB scenarios; run existing offline
   tests and Code Analyzer after production changes. These tests prove control
   logic, not firmware or network timing.
7. Perform only the separately approved controlled hardware/EDF/Data Viewer
   qualification in J; update evidence/handoff/decisions, commit and push checks.
   Preserve unqualified visual/TTL status where measurements are still missing.

Stop at this audit. No M3 executable, callback replacement, participant run,
Host acquisition, time alignment, or hardware integration has been implemented.

## L. Evidence boundaries and actual audit checks

| Evidence class | What was established |
| --- | --- |
| Documented | Installed API help and vendor example/manual behavior, naming and Data Viewer semantics; current primary guidance cross-checks |
| Locally verified | Registry/file versions, x86/x64 import headers, duplicate-copy comparison, which-all resolution, loaded EyeLink SDK version, Screen/IOPort/EyeLink metadata after process-local startup, converter banner, network interface/route state, current GitHub baseline |
| Inferred/recommended | Minimal lifecycle/scheduling, file-only recording request, recovery ownership, first-trial scope, live/final reporting policy and M3 plan |
| Hardware not tested | Host reachability/protocol/firmware, actual calibration/validation/callback/audio behavior, sample/event contents, creation/collision/transfer/recovery, Data Viewer import, API latency, display/TTL timing and external trigger receipt |

Audit commands executed MATLAB R2023b with isolated preferences and made no
persistent path/setting edits. Local diagnostic logs, intentionally ignored:

- `.local/eyelink_audit/runtime.log`: initial path absence, temporary helper
  resolution, PTB/EyeLink versions, native API help; completed successfully.
- `.local/eyelink_audit/saved_path.log`: saved path resolution and loaded EDK;
  stopped with Screen missing-module error before PTB startup.
- `.local/eyelink_audit/startup_metadata.log`: saved path plus installed
  PsychStartup; Screen/IOPort/EyeLink metadata all passed, EDK 2.1.762.0.

The initial restricted network-CIM query was denied by the filesystem/process
sandbox; its read-only retry with permitted access succeeded. This was not a
network configuration failure. No audit claim relies on the denied query.

No MATLAB experiment tests, recording replay, or Code Analyzer were rerun for
this documentation-only audit. Previously recorded M1/M2 automated tests and
PO physical evidence remain in PROJECT_HANDOFF; they are not EyeLink evidence.
Repository checks for this delivery must confirm documentation-only changes,
unchanged tracked MATLAB sources, clean diffs, no staged data/vendor material,
and matching local/remote main after commit/push.

Precommit content checks passed: all required A-L sections are present; all 13
literal absolute paths checked in this document exist; all 21 tracked MATLAB
source/test files match the audited baseline byte for byte after normal Git
line-ending normalization; only this report and PROJECT_HANDOFF are changed.
All 39 local recording directories remain preserved. No M3 executable exists.
