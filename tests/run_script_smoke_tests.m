function run_script_smoke_tests(selection)
%RUN_SCRIPT_SMOKE_TESTS Execute copies of the scripts with isolated PTB stubs.
% Synthetic events exercise software flow only. No hardware is opened.
root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1, selection = 'all'; end
work = tempname(fullfile(root, '.local', 'script_smoke'));
project = fullfile(work, 'project'); stubs = fullfile(work, 'stubs');
if ~isfolder(project), mkdir(project); end
if ~isfolder(stubs), mkdir(stubs); end
files = dir(fullfile(root, '*.m'));
for k = 1:numel(files), copyfile(fullfile(root, files(k).name), project); end
names = {'Screen', 'IOPort', 'GetSecs', 'WaitSecs', 'KbCheck', 'KbName', ...
    'AssertOpenGL', 'ListenChar', 'HideCursor', 'ShowCursor', 'Priority', ...
    'DrawFormattedText', 'GetMouse', 'kPsychGUIWindow', 'input', ...
    'Eyelink', 'EyelinkInitDefaults', 'EyelinkUpdateDefaults', ...
    'EyelinkDoTrackerSetup', 'PsychEyelinkDispatchCallback', 'InitializePsychSound', ...
    'KbReleaseWait', 'PsychStartup', 'which','InitializeMatlabOpenGL', ...
    'glPushAttrib','glEnable','glScissor','glColorMask','glClearColor','glClear','glPopAttrib'};
for k = 1:numel(names)
    fid = fopen(fullfile(stubs, [names{k} '.m']), 'w');
    assert(fid >= 0);
    if strcmp(names{k},'InitializeMatlabOpenGL')
        fprintf(fid, ['function varargout = InitializeMatlabOpenGL(varargin)\n' ...
            'evalin(''caller'',''global GL GLU'');\n' ...
            'global M1_MOCK\n[varargout{1:nargout}]=M1_MOCK.dispatch(''InitializeMatlabOpenGL'',varargin{:});\nend\n']);
        fclose(fid); continue;
    end
    fprintf(fid, ['function varargout = %s(varargin)\n' ...
        'global M1_MOCK\n[varargout{1:nargout}] = M1_MOCK.dispatch(''%s'',varargin{:});\nend\n'], ...
        names{k}, names{k});
    fclose(fid);
end
oldPath = path; oldFolder = pwd;
cleanup = onCleanup(@() restore(oldPath, oldFolder));
addpath(stubs, '-begin'); cd(project);
global M1_MOCK %#ok<GVMIS> Shared by the isolated generated wrappers only.
if strcmp(selection, 'm3'), run_m3_scenarios(project); return; end
if strcmp(selection, 'm5'), run_m5_scenarios(project); return; end
% Both acquisition scripts must work before calibration has ever run.
assert(~isfile(fullfile(project, 'opto_patch.mat')));
reset_mock('cycles'); execute_script('opto_50_cycles');
r = latest_run(project, 'opto_50_cycles');
assert(strcmp(r.summary.result, 'PASS'));
assert_fixed_patch(r);
reset_mock('task'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(r.summary.valid_responses == 10 && all([r.trials.rt_ms] == 250));
assert_fixed_patch(r);
assert(~isfile(fullfile(project, 'opto_patch.mat')));
% Geometry follows the actual window size and rejects an undersized display.
reset_mock('geometry'); M1_MOCK.windowLocal = [0 0 1024 768];
p = m1_patch(100, 2); assert(isequal(p.rect, [0 618 150 768]));
M1_MOCK.windowLocal = [0 0 149 200]; rejected = false;
try
    m1_patch(100, 2);
catch problem
    rejected = strcmp(problem.identifier, 'M1:Display');
end
assert(rejected);
reset_mock('calibration_abort'); execute_script('opto_calibration');
assert(~isfile(fullfile(project, 'opto_patch.mat')) && ~M1_MOCK.displayOpen);
assert(M1_MOCK.preferences.WindowShieldingLevel == 2000 && M1_MOCK.preferences.SkipSyncTests == 0);
% Focused regression: the old unfiltered ismember call rejects this PTB-style
% mixed table. All calibration controls below run against that same table.
rawNames = KbName('KeyNames'); rejected = false;
try
    ismember(rawNames, {'Return'});
catch
    rejected = true;
end
assert(rejected && any(cellfun(@(name) ~ischar(name), rawNames)));
reset_mock('calibration_primary'); execute_script('opto_calibration');
primary = load(fullfile(project, 'opto_patch.mat'));
assert(isequal(primary.patch.desktop_rect, [408 321 568 481]));
assert(isequal(primary.patch.rect, primary.patch.desktop_rect));
reset_mock('calibration'); execute_script('opto_calibration');
saved = load(fullfile(project, 'opto_patch.mat'));
assert(isequal(saved.patch.rect, [408 321 568 481]) && isequal(saved.patch.size_px, [160 160]));
assert(isequal(saved.patch.calibration_rect, [300 200 460 360]));
assert(isequal(saved.patch.desktop_rect, [2328 201 2488 361]));
assert(isequal(saved.patch.calibration_window_rect(1:2), [2028 1]));
assert(isequal(saved.patch.screen_global_rect, [1920 -120 3840 960]));
assert(isequal(saved.patch.resolution, [1920 1080]));
assert(isequal(M1_MOCK.history(1).rect, [20 20 170 170])); % Initial 150 px square.
assert(isequal(M1_MOCK.history(2).rect, [25 20 175 170])); % Arrow key.
assert(isequal(M1_MOCK.history(4).rect, [534 311 684 461])); % Client-area clamp.
assert(isequal(M1_MOCK.history(5).rect, [0 0 150 150]));
assert(~M1_MOCK.history(3).white && ~M1_MOCK.history(4).white); % SPACE held.
assert(M1_MOCK.history(10).white); % Second SPACE toggles back to white.
assert(diff(M1_MOCK.history(7).rect([1 3])) == 160); % Plus.
assert(diff(M1_MOCK.history(8).rect([1 3])) == 160); % Holding plus is one step.
assert(diff(M1_MOCK.history(9).rect([1 3])) == 150); % Minus.
assert(isequal(saved.patch.black, [0 0 0]) && isequal(saved.patch.white, [255 255 255]));
assert(~M1_MOCK.displayOpen && M1_MOCK.cursorVisible && M1_MOCK.listenChar == 0);
assert(isempty(M1_MOCK.commands));
assert(M1_MOCK.backgroundPolls == 2); % BBTK ENTER/ESC/SPACE/arrows ignored.
assert(M1_MOCK.preferences.WindowShieldingLevel == 2000 && M1_MOCK.preferences.SkipSyncTests == 0);
last = M1_MOCK.history(end);
assert(isequal(last.rect + repmat(last.origin, 1, 2), saved.patch.desktop_rect));
bytesBefore = read_bytes(fullfile(project, 'opto_patch.mat'));
reset_mock('calibration_abort'); execute_script('opto_calibration');
assert(isequal(bytesBefore, read_bytes(fullfile(project, 'opto_patch.mat'))));
assert(~M1_MOCK.displayOpen && M1_MOCK.cursorVisible && M1_MOCK.listenChar == 0);
reset_mock('cycles'); execute_script('opto_50_cycles');
r = latest_run(project, 'opto_50_cycles');
assert(strcmp(r.status, 'complete') && strcmp(r.summary.result, 'PASS'));
assert(r.summary.detected_on == 50 && r.summary.detected_off == 50);
assert(numel(r.flips) == 100 && ~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
assert(isequal(M1_MOCK.commands, {'X', sprintf('MOD5\r\n')}));
assert_fixed_patch(r); % Saved calibration has a different position and size.
assert(isequal(bytesBefore, read_bytes(fullfile(project, 'opto_patch.mat'))));
assert(isequal([M1_MOCK.history(2:101).white], repmat([true false], 1, 50)));
assert(all(abs(diff([r.flips.onset_ptb]) - 0.5) < 1e-6));
reset_mock('cycles_silent'); M1_MOCK.preferences.SkipSyncTests = 1;
execute_script('opto_50_cycles');
r = latest_run(project, 'opto_50_cycles');
assert(strcmp(r.summary.result, 'FAIL') && r.summary.missing_events == 100);
assert(r.summary.detected_on == 0 && r.summary.detected_off == 0);
reset_mock('cycles_abort'); M1_MOCK.preferences.SkipSyncTests = 2;
execute_script('opto_50_cycles');
r = latest_run(project, 'opto_50_cycles');
assert(strcmp(r.status, 'aborted') && numel(r.flips) > 0 && numel(r.flips) < 100);
assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
reset_mock('task'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'complete') && r.summary.valid_responses == 10);
assert(all([r.trials.rt_ms] == 250) && all(isfinite([r.trials.button_release_ms])));
assert(r.sync.press_tpad_ms < r.trials(1).optical_on_ms);
assert(sum(strcmp({r.messages.label}, 'SYNC_BUTTON_PRESS')) == 1);
assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
assert_fixed_patch(r);
assert(isequal(bytesBefore, read_bytes(fullfile(project, 'opto_patch.mat'))));
reset_mock('task_missing_onset'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'complete') && isnan(r.trials(3).rt_ms));
assert(strcmp(r.trials(3).response_validity, 'unverified_missing_optical_onset'));
reset_mock('task_abort_sync'); M1_MOCK.preferences.SkipSyncTests = 2;
execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'aborted') && isfinite(r.sync.press_tpad_ms));
assert(isnan(r.sync.release_tpad_ms) && r.summary.presented_trials == 0);
assert(r.summary.event_issues == 0 && r.summary.unavailable_rt == 0);
reset_mock('task_disconnect'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'error') && contains(r.serial_failure, 'Injected'));
assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
reset_mock('cycles_open_error'); M1_MOCK.preferences.SkipSyncTests = 2;
execute_script('opto_50_cycles');
r = latest_run(project, 'opto_50_cycles');
assert(strcmp(r.status, 'error') && contains(r.error, 'Injected window opening failure'));
assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
reset_mock('task_open_error'); M1_MOCK.preferences.SkipSyncTests = 2;
execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'error') && contains(r.error, 'Injected window opening failure'));
assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
% Stale/malformed utility output must not affect acquisition.
unrelated = 1; save(fullfile(project, 'opto_patch.mat'), 'unrelated');
reset_mock('task_ignored_patch'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'complete') && r.summary.valid_responses == 10);
assert_fixed_patch(r);
assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
for scenario = {'cycles_serial_error', 'cycles_serial_error_closed', ...
        'task_serial_error', 'task_serial_error_closed'}
    reset_mock(scenario{1});
    script = 'simple_task';
    if startsWith(scenario{1}, 'cycles'), script = 'opto_50_cycles'; end
    execute_script(script);
    r = latest_run(project, script);
    assert(strcmp(r.status, 'error') && contains(r.error, 'COM5'));
    assert(contains(r.error, 'Close the BBTK app'));
    assert(isempty(M1_MOCK.commands) && ~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
end
for scenario = {'cycles_flip_error', 'task_flip_error'}
    reset_mock(scenario{1});
    script = 'simple_task';
    if startsWith(scenario{1}, 'cycles'), script = 'opto_50_cycles'; end
    execute_script(script);
    r = latest_run(project, script);
    assert(strcmp(r.status, 'error') && contains(r.error, 'Injected display closure'));
    assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
end
for scenario = {'cycles_glitch', 'task_glitch', 'cycles_onset_chatter', ...
        'task_onset_chatter', 'cycles_both_chatter'}
    reset_mock(scenario{1});
    script = 'simple_task';
    if startsWith(scenario{1}, 'cycles'), script = 'opto_50_cycles'; end
    execute_script(script); r = latest_run(project, script);
    if startsWith(scenario{1}, 'cycles')
        pairs = 50; if contains(scenario{1}, 'both'), pairs = 100; end
        assert(strcmp(r.summary.result, 'PASS') && r.summary.ignored_glitch_pairs == pairs);
        assert(r.summary.raw_detected_on == 50 + pairs && r.summary.detected_on == 50);
    else
        assert(r.summary.valid_responses == 10 && all([r.trials.rt_ms] == 250));
        assert(r.summary.event_issues == 0 && r.optical_summary.ignored_glitch_pairs == 10);
        assert(r.optical_summary.raw_detected_on == 20 && r.optical_summary.detected_on == 10);
        assert(r.optical_summary.unexpected_optical_events == 0);
        assert(isfile(fullfile(r.folder, 'optical_summary.csv')));
    end
    assert_fixed_patch(r);
    assert(sum([r.messages.optical_glitch]) > 0);
    assert(~isfield(r.raw_messages, 'optical_glitch'));
    assert(numel(r.raw_messages) == numel(r.messages));
    assert(isfile(fullfile(r.folder, 'raw_messages.csv')) && isfile(fullfile(r.folder, 'optical_pulses.csv')));
end
for scenario = {'cycles_init_write_error', 'cycles_init_timeout', 'cycles_init_abort'}
    reset_mock(scenario{1}); execute_script('opto_50_cycles');
    r = latest_run(project, 'opto_50_cycles');
    assert(~strcmp(r.status, 'complete') && ~isempty(r.serial_failure));
    assert(isfile(fullfile(r.folder, 'raw_rx.bin')) && M1_MOCK.serialCloses == 1);
end
% Repeated stale cleanup must not close a newly reused port/file handle.
reset_mock('ownership'); journals = tempname(work); mkdir(journals);
openFiles = fopen('all');
io = tpad_io('open', [], 'COM5', journals); stale = io;
assert(isempty(io.failure) && io.handle == 0);
io = tpad_io('close', io); %#ok<NASGU>
m1_cleanup(stale, false); m1_cleanup(stale, false);
assert(M1_MOCK.serialCloses == 1 && isequal(fopen('all'), openFiles));
otherJournals = tempname(work); mkdir(otherJournals);
io = tpad_io('open', [], 'COM5', otherJournals);
liveFiles = fopen('all'); m1_cleanup(stale, false);
assert(M1_MOCK.serialOpen && isequal(fopen('all'), liveFiles));
io = tpad_io('close', io); %#ok<NASGU>
assert(M1_MOCK.serialCloses == 2 && M1_MOCK.invalidSerialCloses == 0);
assert(isequal(fopen('all'), openFiles));
fprintf('PASS: 30 simulated script scenarios plus geometry and repeated-cleanup/handle-0 checks.\n');
% M2 reuses this same serial/display fixture; the M1 reference sources stay intact.
for scenario = {'numbered', 'numbered_mixed', 'numbered_abort', ...
        'numbered_disconnect', 'numbered_serial_error', 'numbered_open_error', 'numbered_flip_error'}
    reset_mock(scenario{1}); execute_script('numbered_circle_task');
    r = latest_run(project, 'numbered_circle_task');
    if ismember(scenario{1}, {'numbered', 'numbered_mixed'})
        assert_numbered_run(r, strcmp(scenario{1}, 'numbered_mixed'));
    elseif strcmp(scenario{1}, 'numbered_abort')
        assert(strcmp(r.status, 'aborted') && r.summary.presented_trials == 1);
        assert(~isempty(r.messages) && ~isempty(r.raw_messages));
    else
        assert(strcmp(r.status, 'error'));
    end
    if ~isempty(M1_MOCK.commands), assert(isequal(M1_MOCK.commands, {'X', sprintf('MOD5\r\n')})); end
    if isfile(fullfile(r.folder, 'raw_chunks.csv'))
        chunks = readtable(fullfile(r.folder, 'raw_chunks.csv'));
        raw = read_bytes(fullfile(r.folder, 'raw_rx.bin'));
        if ~isempty(chunks)
            assert(isequal(chunks.byte_offset, [0; cumsum(chunks.byte_count(1:end - 1))]));
            assert(sum(chunks.byte_count) == numel(raw));
        end
    end
end
fprintf('PASS: 7 M2 script scenarios, including mixed four-button responses, grace, missing onset and cleanup.\n');
run_m3_scenarios(project);
run_m5_scenarios(project);
fprintf('No physical GUI/hardware validation.\n');
end

function assert_numbered_run(r, mixed)
global M1_MOCK %#ok<GVMIS>
assert(strcmp(r.status, 'complete') && r.summary.presented_trials == 10);
assert(isequal([r.trials.displayed_digit], [1 2 3 4 1 2 3 4 1 2]));
on = r.flips(strcmp({r.flips.phase}, 'stimulus_on'));
off = r.flips(strcmp({r.flips.phase}, 'stimulus_off'));
fixation = r.flips(strcmp({r.flips.phase}, 'fixation'));
assert(all(abs([off.onset_ptb] - [on.onset_ptb] - 0.5) < 1e-6));
assert(all(abs([on.onset_ptb] - [fixation.onset_ptb] - 1.0) < 1e-6));
assert(all(abs([r.trials.response_deadline_ptb] - [on.onset_ptb] - 1.5) < 1e-6));
assert(isequal(M1_MOCK.digits, r.targets) && r.sync.release_tpad_ms > r.sync.press_tpad_ms);
assert(sum(strcmp({r.messages.label}, 'SYNC_BUTTON_PRESS')) == 1);
syncRelease = r.messages([r.messages.sequence] == r.sync.release_sequence);
assert(fixation(1).onset_ptb >= syncRelease.rx_complete_ptb);
assert(~any([r.trials.button_press_sequence] == r.sync.press_sequence));
assert(isfile(fullfile(r.folder, 'sync.csv')) && isfile(fullfile(r.folder, 'trials.csv')));
assert(isequal(r.patch.rect, [0 930 150 1080]) && ~isfield(r.raw_messages, 'optical_glitch'));
assert(all([r.trials.iti_start_ptb] >= [off.onset_ptb]));
assert(all([fixation(2:end).onset_ptb] - [r.trials(1:9).iti_start_ptb] >= 0.5));
assert(all([r.trials.online_processed_ptb] >= [r.trials.online_received_ptb] | ...
    isnan([r.trials.online_received_ptb])));
if ~mixed
    assert(r.summary.correct == 10 && r.summary.timeouts == 0 && all([r.trials.rt_ms] == 200));
    assert(isequal([r.trials.online_button], r.targets) && all([r.trials.online_correct] == 1));
    assert(isequal([r.trials.online_button_ms], [r.trials.button_press_ms]));
    assert(all([r.trials.online_processed_ptb] < [off.onset_ptb]));
    assert(all([r.trials.iti_start_ptb] - [on.onset_ptb] < 0.55));
    assert(r.summary.valid_optical_onsets == 10 && r.summary.valid_optical_offsets == 10);
else
    assert(r.summary.correct == 5 && r.summary.incorrect == 1 && r.summary.timeouts == 4);
    assert(isequal({r.trials.outcome}, {'CORRECT','INCORRECT','TIMEOUT','TIMEOUT', ...
        'CORRECT','TIMEOUT','CORRECT','CORRECT','CORRECT','TIMEOUT'}));
    assert(r.trials(2).actual_button == 3 && r.trials(2).rt_ms == 900);
    assert(r.trials(2).online_button == 3 && r.trials(2).online_correct == 0);
    assert(r.trials(2).iti_start_ptb - on(2).onset_ptb > 0.9 && ...
        r.trials(2).iti_start_ptb - on(2).onset_ptb < 0.94);
    assert(r.trials(4).late_response && r.trials(10).late_response);
    assert(r.trials(3).premature_response && isnan(r.trials(3).online_response_sequence));
    assert(isnan(r.trials(3).online_received_ptb) && isnan(r.trials(3).online_processed_ptb));
    assert(r.trials(5).extra_presses == 1 && r.trials(5).actual_button == 1);
    assert(r.trials(6).premature_response && isnan(r.trials(6).actual_button));
    heldRelease = r.messages(strcmp({r.messages.channel}, 'A') & [r.messages.sensor] == 2 & ...
        strcmp({r.messages.edge}, 'R') & [r.messages.trial] == 6);
    assert(numel(heldRelease) == 1 && heldRelease.rx_first_ptb > fixation(7).onset_ptb);
    assert(r.trials(7).missing_optical_on && isnan(r.trials(7).rt_ms));
    assert(strcmp(r.trials(7).response_validity, 'unverified_missing_optical_onset'));
    assert(r.trials(7).iti_start_ptb - on(7).onset_ptb < 0.55);
    assert(r.trials(8).rt_ms == 200 && r.trials(8).optical_artifact_pairs == 2);
    assert(r.trials(9).rt_ms == 1490 && r.trials(9).serial_grace_used);
    assert(r.trials(9).iti_start_ptb - on(9).onset_ptb < 1.6);
    assert(all([r.trials([3 4 6 10]).iti_start_ptb] - [on([3 4 6 10]).onset_ptb] >= 1.6 - 1e-6));
end
end

function assert_fixed_patch(run)
global M1_MOCK %#ok<GVMIS>
assert(isequal(run.patch.rect, [0 930 150 1080]));
assert(isequal(run.patch.size_px, [150 150]) && isequal(run.patch.resolution, [1920 1080]));
assert(isequal(run.patch.black, [0 0 0]) && isequal(run.patch.white, [255 255 255]));
assert(~M1_MOCK.history(1).white);
hasRect = arrayfun(@(f) ~isempty(f.rect), M1_MOCK.history);
assert(all(arrayfun(@(f) isequal(f.rect, run.patch.rect), M1_MOCK.history(hasRect))));
assert(sum([M1_MOCK.history.white]) == sum(strcmp({run.flips.expected_edge}, 'P')));
assert(isequal(M1_MOCK.commands, {'X', sprintf('MOD5\r\n')})); % No software TTL.
if strcmp(run.script, 'simple_task')
    assert(isequal([M1_MOCK.history.white], strcmp({M1_MOCK.history.phase}, 'stimulus')));
end
end

function bytes = read_bytes(file)
fid = fopen(file, 'rb');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
end

function output = execute_script(name)
global M1_MOCK %#ok<GVMIS>
previousSync = M1_MOCK.preferences.SkipSyncTests;
previous3D = M1_MOCK.preferences.Enable3DGraphics;
openFiles = fopen('all');
output = evalc(name); % Execute the real script copy with its own local functions.
assert(~contains(output, 'already-destroyed') && ~contains(output, 'onCleanup'' class destructor'), ...
    'A cleanup callback accessed an exiting workspace.');
fprintf('%s', output);
assert(M1_MOCK.preferences.SkipSyncTests == previousSync, 'SkipSyncTests was not restored.');
assert(M1_MOCK.preferences.Enable3DGraphics == previous3D, 'OpenGL preference was not restored.');
assert(isequal(fopen('all'), openFiles), 'A journal file was left open.');
assert(M1_MOCK.invalidDraws == 0 && M1_MOCK.invalidSerialCloses == 0);
assert(M1_MOCK.serialCloses == M1_MOCK.serialOpens && ~M1_MOCK.serialOpen);
if contains(M1_MOCK.scenario, 'serial_error')
    assert(count(output, 'tPAD serial failure on COM5:') == 1);
    assert(~contains(output, 'Invalid window'));
end
if ~strcmp(name, 'opto_calibration')
    assert(contains(output, 'Visual synchronization tests are disabled (SkipSyncTests=1).'));
    assert(contains(output, 'Screen(''Flip'') timestamps are not yet scientifically qualified.'));
end
end

function r = latest_run(project, name)
global M1_MOCK %#ok<GVMIS>
folders = dir(fullfile(project, 'data', [name '_*']));
folders = folders(~ismember({folders.name}, M1_MOCK.previousFolders));
assert(numel(folders) == 1, 'Expected one new run directory.');
saved = load(fullfile(folders.folder, folders.name, 'session.mat'));
r = saved.run;
end

function restore(oldPath, oldFolder)
cd(oldFolder); path(oldPath);
clear global M1_MOCK
end

function reset_mock(scenario)
global M1_MOCK %#ok<GVMIS>
previous = dir(fullfile(pwd, 'data', '*'));
screenGlobal = [1920 -120 3840 960];
if strcmp(scenario, 'calibration_primary'), screenGlobal = [0 0 1920 1080]; end
M1_MOCK = struct('dispatch', @dispatch, 'scenario', scenario, 'time', 0, ...
    'displayOpen', false, 'serialOpen', false, 'mode5', false, ...
    'draftWhite', false, 'white', false, 'draftSync', false, 'syncSent', false, ...
    'draftRect', [], 'cursorVisible', true, 'listenChar', 0, ...
    'history', struct('rect', {}, 'white', {}, 'origin', {}, 'phase', {}), ...
    'digits', [], 'draftDigit', NaN, 'fixations', 0, 'textSize', 24, ...
    'draftPhase', '', 'invalidDraws', 0, 'invalidSerialCloses', 0, ...
    'serialOpens', 0, 'serialCloses', 0, ...
    'preferences', struct('WindowShieldingLevel', 2000, 'SkipSyncTests', 0, 'Enable3DGraphics', 1), ...
    'screenGlobal', screenGlobal, 'windowGlobal', [], 'windowLocal', [], ...
    'windowMoved', false, 'backgroundPolls', 0, ...
    'flips', 0, 'onsets', 0, 'inputs', 0, 'commands', {{}}, ...
    'previousFolders', {{previous.name}}, ...
    'queue', struct('ready', {}, 'bytes', {}));
end

function varargout = dispatch(name, varargin)
global M1_MOCK %#ok<GVMIS>
s = M1_MOCK.scenario;
switch name
    case 'which'
        if ismember(varargin{1}, {'Screen','IOPort','Eyelink'})
            varargout = {[varargin{1} '.' mexext]};
            if isfield(M1_MOCK,'eye') && strcmp(M1_MOCK.eye.scenario,'preflight_error')
                varargout = {[varargin{1} '.m']};
            end
        else
            varargout = {builtin('which', varargin{:})};
        end
    case {'PsychStartup','InitializePsychSound','KbReleaseWait','EyelinkUpdateDefaults'}
        return;
    case 'InitializeMatlabOpenGL', M1_MOCK.preferences.Enable3DGraphics=0;
    case 'PsychEyelinkDispatchCallback'
        varargout={0};
        if isfield(M1_MOCK.eye,'plannedBlocks')
            M1_MOCK.eye.callbackPolls=M1_MOCK.eye.callbackPolls+1;
            if strcmp(M1_MOCK.eye.scenario,'callback_error') && M1_MOCK.eye.calibrations==2
                error('Injected callback failure');
            end
        end
    case 'glPushAttrib', M1_MOCK.eye.glDepth=M1_MOCK.eye.glDepth+1;
    case 'glScissor'
        assert(isequal([varargin{:}],[0 0 150 150]));
    case {'glEnable','glColorMask'}, return;
    case 'glClearColor', assert(isequal([varargin{:}],[0 0 0 1]));
    case 'glClear'
        assert(varargin{1}==16384 && M1_MOCK.eye.glDepth==1);
        M1_MOCK.draftWhite=false;
    case 'glPopAttrib', M1_MOCK.eye.glDepth=M1_MOCK.eye.glDepth-1;
    case 'Eyelink'
        [varargout{1:nargout}] = eye_dispatch(varargin{:});
    case 'EyelinkInitDefaults'
        varargout = {struct('window', varargin{1},'helptext','Official setup instructions')};
    case 'EyelinkDoTrackerSetup'
        if isfield(M1_MOCK.eye,'plannedBlocks')
            e=M1_MOCK.eye; block=e.calibrations+1;
            assert(e.open && ~e.recording && e.stops==block-1 && ~isempty(e.hook));
            assert(M1_MOCK.serialOpen==(block>1) && ~M1_MOCK.white);
            M1_MOCK.eye.calibrations=block; M1_MOCK.eye.accepted=false;
            M1_MOCK.eye.calibrationTimes(end+1)=M1_MOCK.time;
            M1_MOCK.syncSent=false;
            if block>1
                saved=load(fullfile(e.runFolder,'session.mat'));
                assert(strcmp(saved.run.blocks(block-1).status,'COMPLETE'));
                assert(sum(isfinite([saved.run.trials.stimulus_flip_ptb]))==(block-1)*10);
                if strcmp(e.scenario,'boundaries')
                    queue_event(M1_MOCK.time+0.25,sprintf('A P 4 %d',stamp(M1_MOCK.time+0.25)));
                    queue_event(M1_MOCK.time+0.30,sprintf('A R 4 %d',stamp(M1_MOCK.time+0.30)));
                    queue_event(M1_MOCK.time+0.32,sprintf('C P 1 %d',stamp(M1_MOCK.time+0.32)));
                    queue_event(M1_MOCK.time+0.34,sprintf('C R 1 %d',stamp(M1_MOCK.time+0.34)));
                end
            end
            Screen('FillRect',100,[255 255 255],[0 930 150 1080]); Screen('Flip',100);
            assert(~M1_MOCK.white,'SDK calibration frame escaped the black patch mask');
            for callback=1:40
                WaitSecs(0.025); m5_setup_callback([2 0 0 0]);
            end
        else
            assert(M1_MOCK.eye.open && ~M1_MOCK.serialOpen && ~M1_MOCK.eye.recording);
        end
        result = 0;
        if strcmp(M1_MOCK.eye.scenario, 'calibration_error') && ...
                (~isfield(M1_MOCK.eye,'plannedBlocks') || M1_MOCK.eye.calibrations==M1_MOCK.eye.failBlock)
            result = -1;
        end
        M1_MOCK.eye.setup = true; varargout = {result};
    case 'GetSecs'
        limit=100;
        if isfield(M1_MOCK,'eye') && isfield(M1_MOCK.eye,'plannedBlocks'), limit=300; end
        assert(M1_MOCK.time < limit, 'Mock time limit exceeded.');
        varargout = {M1_MOCK.time};
    case 'WaitSecs'
        M1_MOCK.time = M1_MOCK.time + varargin{end};
    case 'input'
        if ~isfield(M1_MOCK, 'eye'), error('Calibration must not prompt for input.'); end
        if contains(varargin{1}, 'HOST CHECKED NONPARTICIPANT')
            assert(M1_MOCK.eye.opens==0 && ~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
            M1_MOCK.eye.diagnosticPrompts = M1_MOCK.eye.diagnosticPrompts + 1;
            answer = 'HOST CHECKED NONPARTICIPANT';
            if ismember(M1_MOCK.eye.scenario, {'read_timeout','filter_malformed','filter_unknown'}), answer = ''; end
            if strcmp(M1_MOCK.eye.scenario, 'diagnostic_wrong_confirmation'), answer = 'YES'; end
            varargout = {answer}; return;
        end
        proposed = regexp(varargin{1}, 'UNUSED (E[A-F0-9]{7})', 'tokens', 'once');
        assert(~isempty(proposed)); M1_MOCK.eye.proposed = proposed{1};
        if strcmp(M1_MOCK.eye.scenario, 'history_collision')
            old = fullfile(pwd, 'data', 'prior_reserved'); mkdir(old);
            eyelink = struct('host_basename', proposed{1});
            save(fullfile(old, 'eyelink_recovery.mat'), 'eyelink');
        end
        answer = ['UNUSED ' proposed{1}];
        if strcmp(M1_MOCK.eye.scenario, 'filename_cancel'), answer = ''; end
        varargout = {answer};
    case 'kPsychGUIWindow'
        varargout = {32};
    case 'KbName'
        keys = repmat({[]}, 1, 256); % PTB leaves unnamed entries as numeric [].
        keys(1:11) = {'ESCAPE', 'space', 'RightArrow', 'LeftArrow', 'DownArrow', 'UpArrow', ...
            'Return', '=+', '-_', '+', '-'};
        keys{12} = 'y';
        keys{128} = 42; % Any non-text slot must be ignored safely.
        if strcmp(varargin{1}, 'UnifyKeyNames'), return; end
        if strcmp(varargin{1}, 'KeyNames'), varargout = {keys}; return; end
        varargout = {find(strcmp(keys, varargin{1}))};
    case 'KbCheck'
        keys = false(1, 256);
        if startsWith(s, 'calibration')
            frame = M1_MOCK.flips;
            assert(frame < 20, 'Calibration did not exit.');
            keys(7) = frame == 0; % ENTER held while launching must not save.
            keys(3) = frame == 1;
            if strcmp(s, 'calibration_abort')
                keys(1) = frame >= 2; keys(8) = frame == 1;
            else
                keys(2) = ismember(frame, [2 3 9]);
                keys(8) = ismember(frame, [6 7 10]); keys(11) = frame == 8;
                keys(7) = frame == 0 || frame >= 12;
                if frame == 8 && M1_MOCK.backgroundPolls < 2
                    keys(:) = false; keys([1 2 3 7 8]) = true;
                end
            end
        elseif strcmp(s, 'cycles_abort')
            keys(1) = M1_MOCK.time > 3;
        elseif strcmp(s, 'task_abort_sync')
            keys(1) = M1_MOCK.syncSent && M1_MOCK.time > 0.72;
        elseif strcmp(s, 'cycles_init_abort')
            keys(1) = M1_MOCK.serialOpen && M1_MOCK.time > 0.02;
        elseif startsWith(s, 'numbered')
            keys(3:6) = true; % Irrelevant PC/HID keys must never become responses.
            keys(1) = strcmp(s, 'numbered_abort') && M1_MOCK.time > 2.1;
        end
        if isfield(M1_MOCK, 'eye') && M1_MOCK.eye.acceptPrompt
            keys(:) = false;
            cancel=strcmp(M1_MOCK.eye.scenario, 'calibration_cancel');
            if isfield(M1_MOCK.eye,'plannedBlocks'), cancel=cancel && M1_MOCK.eye.calibrations==M1_MOCK.eye.failBlock; end
            if cancel, keys(1) = true;
            else
                keys(12) = true; M1_MOCK.eye.accepted = true;
                if isfield(M1_MOCK.eye,'plannedBlocks')
                    M1_MOCK.eye.acceptances=M1_MOCK.eye.acceptances+1;
                    M1_MOCK.eye.acceptedTimes(end+1)=M1_MOCK.time;
                end
            end
            M1_MOCK.eye.acceptPrompt = false;
        elseif isfield(M1_MOCK,'eye') && isfield(M1_MOCK.eye,'plannedBlocks')
            e=M1_MOCK.eye;
            if ismember(e.scenario,{'abort','abort_transfer'}) && M1_MOCK.onsets>=(e.failBlock-1)*10+2, keys(1)=true; end
            if strcmp(e.scenario,'sync_abort') && numel(e.syncTimes)>=e.failBlock && M1_MOCK.time>e.syncTimes(end)+0.15
                keys(1)=true;
            end
        end
        varargout = {any(keys), M1_MOCK.time, keys};
    case 'GetMouse'
        frame = M1_MOCK.flips; point = [0 0]; down = false; focused = true;
        if startsWith(s, 'calibration') && ~strcmp(s, 'calibration_abort')
            if frame >= 8 && ~M1_MOCK.windowMoved
                M1_MOCK.windowGlobal = M1_MOCK.windowGlobal + [40 30 40 30];
                M1_MOCK.windowMoved = true;
            end
            if frame == 8 && M1_MOCK.backgroundPolls < 2
                focused = false; M1_MOCK.backgroundPolls = M1_MOCK.backgroundPolls + 1;
            end
            switch frame
                case 2, point = [35 35]; down = true;
                case 3, point = [3000 2000]; down = true;
                case 4, point = [-100 -100]; down = true;
                case 5, point = [310 215]; down = true;
                case 7, point = [1000 800]; down = true; % Outside: no drag.
                case 8, point = [1700 1000]; down = true;
            end
        end
        varargout = {point(1), point(2), [down false false], focused};
    case 'ListenChar'
        M1_MOCK.listenChar = varargin{1};
    case 'HideCursor'
        M1_MOCK.cursorVisible = false;
    case 'ShowCursor'
        M1_MOCK.cursorVisible = true;
    case 'DrawFormattedText'
        if isfield(M1_MOCK, 'eye') && contains(varargin{2}, 'Press Y')
            M1_MOCK.eye.acceptPrompt = true; return;
        end
        if isfield(M1_MOCK,'eye') && isfield(M1_MOCK.eye,'plannedBlocks') && contains(varargin{2},'EyeLink calibration')
            assert(contains(varargin{2},sprintf('Block %d/4',M1_MOCK.eye.calibrations+1))); return;
        end
        if startsWith(s, 'numbered') && numel(varargin{2}) == 1
            assert(ismember(varargin{2}, '1234') && isequal(varargin{5}, [0 0 0]));
            assert(M1_MOCK.textSize == 48 && strcmp(M1_MOCK.draftPhase, 'stimulus'));
            M1_MOCK.draftDigit = str2double(varargin{2});
        else
            M1_MOCK.draftSync = true; M1_MOCK.draftPhase = 'sync';
        end
    case 'Screen'
        switch varargin{1}
            case 'Version', varargout = {struct('version','3.0.19')};
            case 'Screens'
                screens = [0 2];
                if strcmp(s, 'calibration_primary'), screens = 0; end
                varargout = {screens};
            case 'Preference'
                old = M1_MOCK.preferences.(varargin{2});
                if numel(varargin) >= 3, M1_MOCK.preferences.(varargin{2}) = varargin{3}; end
                varargout = {old};
            case 'Rect'
                local = [0 0 1920 1080];
                if varargin{2} == 100, local = M1_MOCK.windowLocal; end
                varargout = {local};
            case 'GlobalRect'
                globalRect = M1_MOCK.screenGlobal;
                if varargin{2} == 100, globalRect = M1_MOCK.windowGlobal; end
                varargout = {globalRect};
            case 'WindowSize'
                varargout = {M1_MOCK.windowLocal(3), M1_MOCK.windowLocal(4)};
            case 'Windows'
                handles = []; if M1_MOCK.displayOpen, handles = 100; end
                varargout = {handles};
            case 'OpenWindow'
                if startsWith(s, 'calibration')
                    assert(numel(varargin) == 10 && varargin{10} == 32, 'Calibration must use kPsychGUIWindow.');
                    assert(isequal(varargin{4}(3:4) - varargin{4}(1:2), [700 500]));
                    assert(M1_MOCK.preferences.WindowShieldingLevel == 0 && M1_MOCK.listenChar == 0);
                    % Native client origin includes borders/title bar, unlike
                    % the requested outer-window rectangle.
                    origin = varargin{4}(1:2) + [8 31];
                    M1_MOCK.windowLocal = [0 0 684 461];
                    M1_MOCK.windowGlobal = [origin origin + [684 461]];
                else
                    assert(numel(varargin) == 3, 'Acquisition must remain full screen.');
                    assert(M1_MOCK.preferences.WindowShieldingLevel == 2000 && M1_MOCK.preferences.SkipSyncTests == 1);
                    if endsWith(s, '_open_error'), error('Injected window opening failure'); end
                    M1_MOCK.windowLocal = [0 0 1920 1080];
                    M1_MOCK.windowGlobal = M1_MOCK.screenGlobal;
                end
                M1_MOCK.displayOpen = true; varargout = {100, M1_MOCK.windowLocal};
            case 'GetFlipInterval', varargout = {1/60};
            case 'TextSize', M1_MOCK.textSize = varargin{3};
            case 'FillRect'
                if ~M1_MOCK.displayOpen
                    M1_MOCK.invalidDraws = M1_MOCK.invalidDraws + 1;
                    error('Invalid window in FillRect.');
                end
                assert(isequal(varargin{3}, [0 0 0]) || isequal(varargin{3}, [255 255 255]));
                M1_MOCK.draftWhite = any(varargin{3} > 0);
                M1_MOCK.draftRect = [];
                if numel(varargin) == 3
                    M1_MOCK.draftPhase = 'blank'; M1_MOCK.draftDigit = NaN;
                    if isfield(M1_MOCK,'eye') && isfield(M1_MOCK.eye,'plannedBlocks'), M1_MOCK.draftSync=false; end
                end
                if numel(varargin) >= 4, M1_MOCK.draftRect = varargin{4}; end
            case 'DrawLines', M1_MOCK.draftPhase = 'fixation';
            case 'FillOval', M1_MOCK.draftPhase = 'stimulus';
            case 'Flip'
                if isfield(M1_MOCK,'eye') && isfield(M1_MOCK.eye,'plannedBlocks') && ~isempty(M1_MOCK.eye.hook)
                    eval(M1_MOCK.eye.hook);
                end
                if ~M1_MOCK.displayOpen
                    M1_MOCK.invalidDraws = M1_MOCK.invalidDraws + 1;
                    error('Invalid window in Flip.');
                end
                if endsWith(s, '_flip_error') && M1_MOCK.draftWhite
                    M1_MOCK.displayOpen = false; error('Injected display closure');
                end
                earliest = M1_MOCK.time;
                if numel(varargin) >= 3, earliest = max(earliest, varargin{3}); end
                vbl = (floor(earliest * 60 + 1e-8) + 1) / 60;
                M1_MOCK.time = vbl + 0.0001; M1_MOCK.flips = M1_MOCK.flips + 1;
                M1_MOCK.history(end + 1) = struct('rect', M1_MOCK.draftRect, ...
                    'white', M1_MOCK.draftWhite, 'origin', M1_MOCK.windowGlobal(1:2), ...
                    'phase', M1_MOCK.draftPhase);
                if startsWith(s, 'numbered') && strcmp(M1_MOCK.draftPhase, 'fixation')
                    M1_MOCK.fixations = M1_MOCK.fixations + 1;
                    fixation=M1_MOCK.fixations;
                    if isfield(M1_MOCK,'eye') && isfield(M1_MOCK.eye,'plannedBlocks'), fixation=mod(fixation-1,10)+1; end
                    if strcmp(s, 'numbered_mixed') && fixation == 6
                        queue_event(vbl + 0.204, sprintf('A P 2 %d', stamp(vbl + 0.2)));
                        queue_event(vbl + 3.204, sprintf('A R 2 %d', stamp(vbl + 3.2)));
                    end
                end
                if startsWith(s, 'numbered') && M1_MOCK.draftWhite
                    assert(isequal(M1_MOCK.draftRect, [0 930 150 1080]));
                    M1_MOCK.digits(end + 1) = M1_MOCK.draftDigit;
                end
                if M1_MOCK.mode5 && M1_MOCK.draftWhite ~= M1_MOCK.white
                    edge = 'R';
                    if M1_MOCK.draftWhite
                        edge = 'P'; M1_MOCK.onsets = M1_MOCK.onsets + 1;
                    end
                    opticalTrial=M1_MOCK.onsets;
                    if isfield(M1_MOCK,'eye') && isfield(M1_MOCK.eye,'plannedBlocks'), opticalTrial=mod(opticalTrial-1,10)+1; end
                    missing = (strcmp(s, 'task_missing_onset') && M1_MOCK.onsets == 3 || ...
                        strcmp(s, 'numbered_mixed') && opticalTrial == 7) && edge == 'P';
                    chatter = strcmp(s, 'numbered_mixed') && opticalTrial == 8;
                    if strcmp(s, 'numbered_snapshot') && M1_MOCK.onsets == 1 && edge == 'P'
                        queue_event(vbl + 0.001, sprintf('C P 1 %d', stamp(vbl)));
                        queue_event(vbl + 0.002, sprintf('C R 1 %d', stamp(vbl)));
                    end
                    delayedOff = strcmp(s, 'numbered_snapshot') && M1_MOCK.onsets == 1 && edge == 'R';
                    if isfield(M1_MOCK,'eye') && strcmp(M1_MOCK.eye.scenario,'boundaries') && opticalTrial==10 && edge=='R'
                        delayedOff=true;
                    end
                    if delayedOff
                        M1_MOCK.queue(end+1) = struct('ready', vbl+0.004, 'bytes', uint8('C R 1 '));
                        delay=0.55;
                        if isfield(M1_MOCK,'eye') && strcmp(M1_MOCK.eye.scenario,'boundaries'), delay=0.65; end
                        queue_event(vbl+delay, sprintf('%d', stamp(vbl)));
                    end
                    if ~strcmp(s, 'cycles_silent') && ~missing && ~delayedOff
                        if (endsWith(s, '_onset_chatter') || contains(s, '_both_chatter')) && edge == 'P'
                            queue_event(vbl + 0.001, sprintf('C P 1 %d', stamp(vbl)));
                            queue_event(vbl + 0.002, sprintf('C R 1 %d', stamp(vbl)));
                        end
                        offset = 0;
                        if chatter && edge == 'P'
                            queue_event(vbl + 0.001, sprintf('C P 1 %d', stamp(vbl)));
                            queue_event(vbl + 0.002, sprintf('C R 1 %d', stamp(vbl) + 2));
                            offset = 2;
                        end
                        queue_event(vbl + 0.004, sprintf('C %s 1 %d', edge, stamp(vbl) + offset));
                    end
                    if (endsWith(s, '_glitch') || contains(s, '_both_chatter') || chatter) && edge == 'R'
                        queue_event(vbl + 0.005, sprintf('C P 1 %d', stamp(vbl) + 1));
                        queue_event(vbl + 0.007, sprintf('C R 1 %d', stamp(vbl) + 3));
                    end
                    if startsWith(s, 'task') && edge == 'P'
                        queue_event(vbl + 0.254, sprintf('A P 1 %d', stamp(vbl + 0.25)));
                        queue_event(vbl + 0.904, sprintf('A R 1 %d', stamp(vbl + 0.9)));
                    end
                    if startsWith(s, 'numbered') && edge == 'P'
                        if isfield(M1_MOCK,'eye') && strcmp(M1_MOCK.eye.scenario,'boundaries') && ...
                                M1_MOCK.onsets>10 && opticalTrial==1
                            queue_event(vbl+0.001,sprintf('A P 3 %d',stamp(vbl)-5000));
                            queue_event(vbl+0.002,sprintf('A R 3 %d',stamp(vbl)-4950));
                        end
                        queue_numbered_response(s, M1_MOCK.onsets, vbl);
                    end
                end
                M1_MOCK.white = M1_MOCK.draftWhite;
                if M1_MOCK.draftSync && ~M1_MOCK.syncSent
                    if isfield(M1_MOCK, 'eye')
                        expected=1;
                        if isfield(M1_MOCK.eye,'plannedBlocks'), expected=M1_MOCK.eye.calibrations; end
                        assert(M1_MOCK.eye.recording && M1_MOCK.eye.starts == expected);
                        M1_MOCK.eye.syncTime = vbl;
                        if isfield(M1_MOCK.eye,'plannedBlocks'), M1_MOCK.eye.syncTimes(end+1)=vbl; end
                    end
                    M1_MOCK.syncSent = true;
                    queue_event(vbl + 0.104, sprintf('A P 1 %d', stamp(vbl + 0.1)));
                    queue_event(vbl + 0.204, sprintf('A R 1 %d', stamp(vbl + 0.2)));
                end
                varargout = {vbl, vbl, M1_MOCK.time, -0.001};
            case 'CloseAll', M1_MOCK.displayOpen = false;
            case 'HookFunction'
                operation=varargin{3};
                if strcmp(operation,'AppendMFunction'), M1_MOCK.eye.hook=varargin{6}; end
                if strcmp(operation,'Query'), varargout={-double(isempty(M1_MOCK.eye.hook))}; end
                if strcmp(operation,'Remove'), M1_MOCK.eye.hook=''; end
        end
    case 'IOPort'
        switch varargin{1}
            case 'Version', varargout = {struct('version','3.0.19')};
            case 'OpenSerialPort'
                if isfield(M1_MOCK,'eye')
                    assert(M1_MOCK.eye.accepted && M1_MOCK.eye.open && ~M1_MOCK.eye.recording);
                end
                assert(contains(varargin{3}, 'BaudRate=115200 DataBits=8 Parity=None StopBits=1'));
                assert(contains(varargin{3}, 'FlowControl=None'));
                if contains(s, 'serial_error')
                    if endsWith(s, '_closed'), M1_MOCK.displayOpen = false; end
                    if startsWith(s, 'cycles'), error('COM5 is in use by the BBTK application'); end
                    varargout = {-1, 'COM5 is in use by the BBTK application'}; return;
                end
                assert(~M1_MOCK.serialOpen);
                M1_MOCK.serialOpen = true;
                M1_MOCK.serialOpens = M1_MOCK.serialOpens + 1;
                varargout = {0, ''}; % PTB's first valid handle can be zero.
            case 'Write'
                text = char(varargin{3}); M1_MOCK.commands{end + 1} = text;
                if strcmp(s, 'cycles_init_write_error'), error('Injected setup write failure'); end
                if strcmp(text, 'X')
                    M1_MOCK.mode5 = false;
                    if ~strcmp(s, 'cycles_init_timeout'), queue_event(M1_MOCK.time, 'MODE 0:'); end
                elseif strcmp(text, sprintf('MOD5\r\n'))
                    M1_MOCK.mode5 = true; queue_event(M1_MOCK.time, 'MODE 5:');
                else
                    error('Unexpected serial write.');
                end
                varargout = {numel(text), M1_MOCK.time, ''};
            case 'Read'
                assert(varargin{3} == 0, 'A serial read tried to block.');
                bytes = uint8([]); err = '';
                if strcmp(s, 'task_disconnect') && M1_MOCK.time > 3
                    err = 'Injected serial disconnection';
                elseif strcmp(s, 'numbered_disconnect') && M1_MOCK.time > 2.1
                    err = 'Injected serial disconnection';
                elseif isfield(M1_MOCK,'eye') && strcmp(M1_MOCK.eye.scenario,'serial_disconnect') && ...
                        M1_MOCK.onsets>=(M1_MOCK.eye.failBlock-1)*10+2
                    err='Injected serial disconnection';
                elseif ~isempty(M1_MOCK.queue) && M1_MOCK.queue(1).ready <= M1_MOCK.time
                    n = min(3, numel(M1_MOCK.queue(1).bytes));
                    bytes = M1_MOCK.queue(1).bytes(1:n);
                    M1_MOCK.queue(1).bytes(1:n) = [];
                    if isempty(M1_MOCK.queue(1).bytes), M1_MOCK.queue(1) = []; end
                end
                varargout = {bytes, M1_MOCK.time, err};
            case 'Close'
                if varargin{2} ~= 0 || ~M1_MOCK.serialOpen
                    M1_MOCK.invalidSerialCloses = M1_MOCK.invalidSerialCloses + 1;
                    error('Invalid serial handle.');
                end
                M1_MOCK.serialOpen = false;
                M1_MOCK.serialCloses = M1_MOCK.serialCloses + 1;
        end
end
end

function value = stamp(seconds)
value = 500000 + round(seconds * 1000);
end

function queue_event(ready, text)
global M1_MOCK %#ok<GVMIS>
M1_MOCK.queue(end + 1) = struct('ready', ready, 'bytes', uint8(sprintf('%s\r\n', text)));
[~, order] = sort([M1_MOCK.queue.ready]); M1_MOCK.queue = M1_MOCK.queue(order);
end

function queue_numbered_response(scenario, trial, onset)
global M1_MOCK %#ok<GVMIS>
if isfield(M1_MOCK,'eye') && isfield(M1_MOCK.eye,'plannedBlocks'), trial=mod(trial-1,10)+1; end
targets = [1 2 3 4 1 2 3 4 1 2]; button = targets(trial);
hardwareDelay = 0.2; receiptDelay = 0.204;
if strcmp(scenario, 'numbered_mixed')
    switch trial
        case 3
            % Physical fixation press arrives before the optical ON is parsed.
            queue_event(onset + 0.001, sprintf('A P 4 %d', stamp(onset) - 1));
            queue_event(onset + 0.054, sprintf('A R 4 %d', stamp(onset + 0.05)));
            return;
        case 6, return;
        case 2, button = 3; hardwareDelay = 0.9; receiptDelay = 0.904;
        case 4, hardwareDelay = 1.55; receiptDelay = 1.554;
        case 8, hardwareDelay = 0.202; receiptDelay = 0.206;
        case 9, hardwareDelay = 1.49; receiptDelay = 1.510;
        case 10, hardwareDelay = 1.501; receiptDelay = 1.505;
    end
end
queue_event(onset + receiptDelay, sprintf('A P %d %d', button, stamp(onset + hardwareDelay)));
queue_event(onset + receiptDelay + 0.05, sprintf('A R %d %d', button, stamp(onset + hardwareDelay + 0.05)));
if strcmp(scenario, 'numbered_mixed') && trial == 5
    queue_event(onset + 0.304, sprintf('A P 2 %d', stamp(onset + 0.3)));
    queue_event(onset + 0.354, sprintf('A R 2 %d', stamp(onset + 0.35)));
end
end

function run_m3_scenarios(project)
global M1_MOCK %#ok<GVMIS>
cases = {'real_host_filters','numbered'; 'host_filter_whitespace','numbered'; ...
    'filter_malformed','numbered'; 'filter_unknown','numbered'; 'filter_missing','numbered'; ...
    'normal','numbered'; 'mixed','numbered_mixed'; 'snapshot','numbered_snapshot'; ...
    'dummy','numbered'; 'connect_error','numbered'; 'owned_elsewhere','numbered'; ...
    'preflight_error','numbered'; 'openfile_error','numbered'; ...
    'filename_cancel','numbered'; 'history_collision','numbered'; ...
    'filters_disabled','numbered'; 'read_timeout','numbered'; ...
    'first_empty','numbered'; 'third_valid','numbered'; 'event_first_empty','numbered'; ...
    'unverified_confirm','numbered'; 'sample_unverified','numbered'; 'unusable_reply','numbered'; ...
    'event_missing','numbered'; 'missing_after_empty','numbered'; 'unverified_then_missing','numbered'; ...
    'status_error','numbered'; 'status_error_after_empty','numbered'; 'query_exception','numbered'; ...
    'diagnostic_wrong_confirmation','numbered'; 'disabled_none','numbered'; ...
    'calibration_cancel','numbered'; 'calibration_error','numbered'; ...
    'start_error','numbered'; 'recording_error','numbered'; ...
    'transfer_interrupted','numbered'; 'transfer_mismatch','numbered'; 'destination_exists','numbered'; ...
    'close_error','numbered'; 'stop_error','numbered'; 'message_error','numbered'; ...
    'slow_message','numbered'; 'abort','numbered_abort'; 'disconnect','numbered_disconnect'; ...
    'serial_error','numbered_serial_error'; 'open_error','numbered_open_error'; ...
    'flip_error','numbered_flip_error'};
for k = 1:size(cases, 1)
    reset_mock(cases{k,2});
    if ismember(cases{k,1},{'abort','start_error'}), M1_MOCK.preferences.SkipSyncTests=2; end
    M1_MOCK.eye = struct('scenario',cases{k,1},'connected',strcmp(cases{k,1},'owned_elsewhere'), ...
        'recording',false,'open',false,'setup',false,'acceptPrompt',false,'accepted',false, ...
        'starts',0,'stops',0,'closes',0,'shutdowns',0,'opens',0,'initializes',0,'receives',0, ...
        'startTime',NaN,'syncTime',NaN,'messages',{{}},'messageTimes',[], ...
        'operations',{{}},'proposed','','queryCounts',struct,'diagnosticPrompts',0);
    output = execute_script('numbered_circle_eyelink'); r = latest_run(project, 'numbered_circle_eyelink');
    e = M1_MOCK.eye;
    assert(isfield(r,'eyelink') && r.eyelink.finished);
    assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
    assert(e.shutdowns <= 1 && e.closes <= 1 && e.stops <= 1 && e.starts <= 1);
    assert(e.stops == e.starts && e.closes == e.opens);
    if ismember(e.scenario, {'owned_elsewhere','preflight_error'})
        assert(e.initializes == 0 && e.shutdowns == 0);
    else
        assert(e.shutdowns == 1);
    end
    if ismember(e.scenario, {'normal','mixed','snapshot','first_empty','third_valid','event_first_empty', ...
            'unverified_confirm','sample_unverified','unusable_reply','real_host_filters','host_filter_whitespace'})
        assert(strcmp(r.status,'complete') && e.starts==1 && e.receives==1);
        assert(r.eyelink.transfer_verified && r.eyelink.transfer_bytes==16);
        assert(r.eyelink.filename_confirmed && r.eyelink.calibration_accepted);
        assert(e.startTime < e.syncTime && e.syncTime < r.trials(1).stimulus_flip_ptb);
        ids = e.messages(startsWith(e.messages,'TRIALID '));
        assert(isequal(ids, arrayfun(@(n)sprintf('TRIALID %d',n),1:10,'UniformOutput',false)));
        results = find(startsWith(e.messages,'TRIAL_RESULT '));
        beginnings = find(startsWith(e.messages,'TRIALID '));
        assert(numel(results)==10 && all(results>beginnings));
        assert(all(results(1:9)<beginnings(2:10)));
        assert(e.messageTimes(beginnings(1)) < e.startTime);
        display = find(startsWith(e.messages,'DISPLAY_COORDS '));
        session = find(startsWith(e.messages,'SESSION_START '));
        syncMessage = find(startsWith(e.messages,'TPAD_SYNC '));
        assert(isscalar(display) && display<beginnings(1));
        assert(isscalar(session) && session<syncMessage);
        assert(e.messageTimes(session)>=e.startTime+0.1);
        ordered = {'Initialize','OpenFile','StartRecording','StopRecording','CloseFile','ReceiveFile','Shutdown'};
        indices=cellfun(@(name)find(strcmp(e.operations,name),1),ordered);
        assert(all(diff(indices)>0));
        assert(sum(startsWith(e.messages,'STIMULUS_ONSET '))==10);
        assert(sum(startsWith(e.messages,'STIMULUS_OFFSET '))==10);
        assert(sum(startsWith(e.messages,'TPAD_SYNC '))==1);
        vars = find(startsWith(e.messages,'!V TRIAL_VAR '));
        for j=vars
            assert(any(beginnings<j & results>j), 'Variable outside an open trial');
        end
        assert(~isempty(r.eyelink.poll_gaps) && all([r.eyelink.calls.duration_s]>=0));
        if strcmp(e.scenario,'snapshot')
            assert(r.trials(1).rt_ms==200 && r.trials(1).optical_artifact_pairs==1);
            first = e.messages(beginnings(1):results(1));
            assert(any(strcmp(first,'!V TRIAL_VAR hardware_rt_ms_snapshot NA')));
            assert(any(strcmp(first,'!V TRIAL_VAR analysis_stage ONLINE_SNAPSHOT')));
        else
            assert_numbered_run(r,strcmp(e.scenario,'mixed'));
        end
    elseif ismember(e.scenario, {'filename_cancel','calibration_cancel','abort','read_timeout', ...
            'diagnostic_wrong_confirmation','filter_malformed','filter_unknown'})
        assert(strcmp(r.status,'aborted'));
    else
        assert(strcmp(r.status,'error'), e.scenario);
    end
    if ismember(e.scenario, {'filename_cancel','history_collision','dummy','connect_error', ...
            'owned_elsewhere','preflight_error','filters_disabled','read_timeout'})
        assert(e.opens==0 && e.starts==0);
    end
    if ismember(e.scenario, {'calibration_cancel','calibration_error'})
        assert(e.starts==0 && M1_MOCK.serialOpens==0);
    end
    if strcmp(e.scenario,'history_collision')
        old=fullfile(project,'data','prior_reserved','eyelink_recovery.mat');
        assert(isfile(old)); % Retain it: subsequent runs must avoid this historical name.
    end
    if strcmp(e.scenario,'transfer_interrupted')
        assert(~r.eyelink.transfer_verified && isfile(r.eyelink.local_edf));
        assert(strcmp(char(read_bytes(r.eyelink.local_edf))','PARTIAL'));
        assert(~isempty(r.raw_messages) && isfile(fullfile(r.folder,'raw_rx.bin')));
    end
    if strcmp(e.scenario,'destination_exists')
        assert(e.receives==0 && strcmp(char(read_bytes(r.eyelink.local_edf))','KEEP'));
    end
    if strcmp(e.scenario,'slow_message')
        assert(any([r.eyelink.poll_gaps.gap_s]>=0.25) && r.summary.presented_trials==1);
        assert(contains(r.eyelink.failure,'250 ms'));
    end
    if strcmp(e.scenario,'recording_error'), assert(r.summary.presented_trials==2); end
    if strcmp(e.scenario,'start_error'), assert(r.summary.presented_trials==0); end
    assert_filter_queries(r, e, output);
    if e.opens
        assert(~isempty(regexp(r.eyelink.host_basename,'^E[0-9A-F]{7}$','once')));
        saved=load(fullfile(r.folder,'eyelink_recovery.mat'));
        assert(strcmp(saved.eyelink.run_id,r.eyelink.run_id));
    end
end
fprintf('PASS: %d M3 real-script scenarios, with isolated EyeLink/PTB/tPAD mocks.\n',size(cases,1));
end

function assert_filter_queries(r, e, output)
global M1_MOCK %#ok<GVMIS>
fields = fieldnames(r.eyelink.filters);
assert(r.eyelink.edf_validation_required);
saved=load(fullfile(r.folder,'eyelink_recovery.mat'));
assert(isequaln(saved.eyelink.filters,r.eyelink.filters));
for name={'filter_configuration','host_configuration_confirmed','nonparticipant_diagnostic','edf_validation_required'}
    assert(isequal(saved.eyelink.(name{1}),r.eyelink.(name{1})));
end
for k=1:numel(fields)
    name=fields{k}; item=r.eyelink.filters.(name); a=item.attempts;
    assert(numel(a)>=1 && numel(a)<=3 && isequal([a.number],1:numel(a)));
    assert(numel(a)==e.queryCounts.(name));
    assert(isequaln(item.reply,a(end).raw_reply) && isequaln(item.status,a(end).status));
    assert(count(output,['EyeLink ' name ' attempt '])==numel(a));
    for j=1:numel(a)
        assert(contains(output,sprintf('outcome=%s; raw reply (%s):',a(j).outcome,class(a(j).raw_reply))));
        if j<numel(a), assert(strcmp(a(j).outcome,'UNUSABLE') && a(j).status==0); end
    end
    calls=r.eyelink.calls(strcmp({r.eyelink.calls.operation},'ReadFromTracker') & ...
        strcmp({r.eyelink.calls.text},name));
    assert(all([calls(2:end).start_ptb]-[calls(1:end-1).end_ptb]>=0.05-1e-10));
end
if strcmp(r.eyelink.filter_configuration,'VERIFIED')
    assert(e.diagnosticPrompts==0 && ~r.eyelink.nonparticipant_diagnostic);
    assert(all(cellfun(@(name)strcmp(r.eyelink.filters.(name).verification,'VERIFIED'),fields)));
elseif strcmp(r.eyelink.filter_configuration,'UNVERIFIED')
    assert(e.diagnosticPrompts==1 && contains(output,'WARNING: Host filter configuration UNVERIFIED'));
    assert(contains(output,'Post-recording EDF/EDF2ASC validation is required'));
    assert(r.eyelink.host_configuration_confirmed==r.eyelink.nonparticipant_diagnostic);
    if ~r.eyelink.host_configuration_confirmed
        assert(strcmp(r.status,'aborted') && e.opens==0 && e.starts==0);
    end
elseif ismember(r.eyelink.filter_configuration,{'INVALID','QUERY_ERROR'})
    assert(e.diagnosticPrompts==0 && e.opens==0 && e.starts==0 && strcmp(r.status,'error'));
    assert(~r.eyelink.host_configuration_confirmed && ~r.eyelink.nonparticipant_diagnostic);
end
if ismember(e.scenario,{'first_empty','missing_after_empty','status_error_after_empty'})
    assert(e.queryCounts.file_sample_data==2);
elseif strcmp(e.scenario,'third_valid')
    assert(e.queryCounts.file_sample_data==3 && isstring(r.eyelink.filters.file_sample_data.reply));
elseif strcmp(e.scenario,'event_first_empty')
    assert(e.queryCounts.file_sample_data==1 && e.queryCounts.file_event_filter==2);
elseif ismember(e.scenario,{'read_timeout','unverified_confirm','diagnostic_wrong_confirmation'})
    assert(e.queryCounts.file_sample_data==3 && e.queryCounts.file_event_filter==3);
elseif ismember(e.scenario,{'sample_unverified','unusable_reply','unverified_then_missing'})
    assert(e.queryCounts.file_sample_data==3 && e.queryCounts.file_event_filter==1);
end
if ismember(e.scenario,{'real_host_filters','host_filter_whitespace'})
    expected={'AREA,BUTTON,GAZE,GAZERES,LEFT,RIGHT,STATUS,HMARKER,HMARKER,', ...
        'RIGHT, LEFT, BLINK, FIXATION, SACCADE, MESSAGE, BUTTON, INPUT,'};
    names={'file_sample_data','file_event_filter'};
    assert(strcmp(r.eyelink.filter_configuration,'VERIFIED') && e.diagnosticPrompts==0);
    for k=1:2
        raw=expected{k};
        if strcmp(e.scenario,'host_filter_whitespace'), raw=sprintf(' \t%s , \t',raw(1:end-1)); end
        item=r.eyelink.filters.(names{k});
        assert(e.queryCounts.(names{k})==1 && numel(item.attempts)==1);
        assert(strcmp(item.verification,'VERIFIED') && item.status==0);
        assert(strcmp(item.reply,raw) && strcmp(item.attempts.raw_reply,raw) && contains(output,raw));
    end
elseif ismember(e.scenario,{'filter_malformed','filter_unknown'})
    assert(e.queryCounts.file_sample_data==3 && e.queryCounts.file_event_filter==1);
    assert(strcmp(r.eyelink.filter_configuration,'UNVERIFIED') && e.opens==0);
    assert(all(strcmp({r.eyelink.filters.file_sample_data.attempts.outcome},'UNUSABLE')));
end
if strcmp(e.scenario,'unusable_reply')
    a=r.eyelink.filters.file_sample_data.attempts;
    assert(isequal(a(1).raw_reply,sprintf(' \t ')) && isequal(a(2).raw_reply,{42}));
    assert(strcmp(a(3).raw_reply,'UNREADABLE ???'));
end
if ismember(e.scenario,{'filters_disabled','missing_after_empty','disabled_none','filter_missing'})
    assert(contains(r.error,'lacks GAZE') && strcmp(r.eyelink.filter_configuration,'INVALID'));
    if strcmp(e.scenario,'filter_missing'), assert(e.queryCounts.file_sample_data==1); end
elseif ismember(e.scenario,{'event_missing','unverified_then_missing'})
    assert(contains(r.error,'lacks FIXATION,SACCADE,BLINK,MESSAGE'));
elseif ismember(e.scenario,{'status_error','status_error_after_empty'})
    assert(r.eyelink.filters.file_sample_data.status==-1 && contains(r.error,'nonzero status'));
elseif strcmp(e.scenario,'query_exception')
    a=r.eyelink.filters.file_sample_data.attempts;
    assert(numel(a)==1 && isnan(a.status) && contains(a.error,'Injected query exception'));
end
if ~isempty(fields) && e.opens==0
    assert(e.starts==0 && e.closes==0 && ~r.eyelink.connection_owned);
    assert(M1_MOCK.serialOpens==0);
end
end

function run_m5_scenarios(project)
global M1_MOCK %#ok<GVMIS>
cases={'normal',0;'mixed',0;'boundaries',0; ...
    'calibration_cancel',1;'calibration_cancel',2;'calibration_cancel',4;'calibration_error',3; ...
    'callback_error',2;'abort',2;'sync_abort',3;'tracker_disconnect',3; ...
    'recording_error',4;'start_error',2;'stop_error',3;'slow_message',2; ...
    'serial_disconnect',2;'abort_transfer',3;'transfer_interrupted',0;'transfer_mismatch',0;'close_error',0};
for c=1:size(cases,1)
    scenario='numbered'; if strcmp(cases{c,1},'mixed'), scenario='numbered_mixed'; end
    reset_mock(scenario); M1_MOCK.preferences.SkipSyncTests=2;
    M1_MOCK.eye=struct('scenario',cases{c,1},'failBlock',cases{c,2},'plannedBlocks',4, ...
        'connected',false,'recording',false,'open',false,'setup',false, ...
        'acceptPrompt',false,'accepted',false,'starts',0,'stops',0,'closes',0, ...
        'shutdowns',0,'opens',0,'initializes',0,'receives',0, ...
        'startTime',NaN,'syncTime',NaN,'messages',{{}},'messageTimes',[], ...
        'operations',{{}},'proposed','','queryCounts',struct,'diagnosticPrompts',0, ...
        'calibrations',0,'acceptances',0,'startTimes',[],'stopTimes',[], ...
        'syncTimes',[],'calibrationTimes',[],'acceptedTimes',[], ...
        'hook','','glDepth',0,'callbackPolls',0);
    output=execute_script('numbered_circle_eyelink_4blocks');
    r=latest_run(project,'numbered_circle_eyelink_4blocks'); e=M1_MOCK.eye;
    assert(e.initializes==1 && e.opens==1 && e.closes==1 && e.shutdowns==1);
    assert(e.starts==e.stops && e.starts<=4 && isempty(e.hook) && e.glDepth==0);
    nonStim=~strcmp({M1_MOCK.history.phase},'stimulus');
    assert(~any([M1_MOCK.history(nonStim).white]));
    expectedSerial=double(e.acceptances>0);
    assert(M1_MOCK.serialOpens==expectedSerial && M1_MOCK.serialCloses==expectedSerial);
    if expectedSerial, assert(isequal(M1_MOCK.commands,{'X',sprintf('MOD5\r\n')}));
    else, assert(isempty(M1_MOCK.commands)); end
    assert(r.eyelink.finished && ~r.eyelink.connection_owned && ~r.eyelink.segment_active);
    assert(numel(r.trials)==40 && numel(r.blocks)==4 && numel(r.calibrations)==4 && numel(r.sync)==4);
    assert(isequal([r.trials.global_trial],1:40));
    assert(isequal([r.trials.block_number],repelem(1:4,10)));
    assert(isequal([r.trials.trial_in_block],repmat(1:10,1,4)));
    assert(isequal([r.trials.displayed_digit],repmat([1 2 3 4 1 2 3 4 1 2],1,4)));
    assert(~isfield(r.raw_messages,'optical_glitch'));
    if ~isempty(r.raw_messages)
        assert(isequaln([r.raw_messages.tpad_ms],[r.messages.tpad_ms]));
        assert(isequal({r.raw_messages.raw_hex},{r.messages.raw_hex}));
        assert(issorted([r.messages.sequence]) && numel(unique([r.messages.sequence]))==numel(r.messages));
    else
        assert(isempty(r.messages));
    end
    assert(~any(ismember([r.trials.button_press_sequence],[r.sync.press_sequence])));
    saved=load(fullfile(r.folder,'eyelink_recovery.mat'));
    assert(isequaln(saved.eyelink.calibrations,r.calibrations));
    assert(sum([r.calibrations.accepted])==e.acceptances);
    assert(~any([r.calibrations.machine_verified]));
    accepted=r.calibrations([r.calibrations.accepted]);
    assert(all([accepted.new_calibration_operator_confirmed] & [accepted.new_validation_operator_confirmed]));
    assert(all(strcmp({accepted.verification},'OPERATOR_CONFIRMED')));
    assert(all(e.calibrationTimes(1:e.acceptances)<=e.acceptedTimes));
    for name={'blocks.csv','block_summaries.csv','calibrations.csv','sync.csv','trials.csv'}
        assert(isfile(fullfile(r.folder,name{1})));
    end
    if expectedSerial, assert(isfile(fullfile(r.folder,'raw_rx.bin'))); end
    on=r.flips(strcmp({r.flips.phase},'stimulus_on'));
    off=r.flips(strcmp({r.flips.phase},'stimulus_off'));
    fixation=r.flips(strcmp({r.flips.phase},'fixation'));
    assert(all(abs([on.onset_ptb]-[fixation(1:numel(on)).onset_ptb]-1.0)<1e-6));
    ordinary=off([off.expected_edge]=='R');
    assert(all(abs([ordinary.onset_ptb]-[on(1:numel(ordinary)).onset_ptb]-0.5)<1e-6));
    presented=isfinite([r.trials.stimulus_flip_ptb]);
    assert(all(abs([r.trials(presented).response_deadline_ptb]-[r.trials(presented).stimulus_flip_ptb]-1.5)<1e-6));
    for b=1:4
        ids=(b-1)*10+(1:10); closed=isfinite([r.trials(ids).iti_start_ptb]);
        localFix=fixation([fixation.trial]>(b-1)*10 & [fixation.trial]<=b*10);
        for j=2:numel(localFix)
            if closed(j-1), assert(localFix(j).onset_ptb-r.trials(ids(j-1)).iti_start_ptb>=0.5-1e-8); end
        end
        if b<=e.starts
            assert(r.eyelink.segments(b).start_attempted && r.eyelink.segments(b).stop_attempted);
        end
        if b<e.calibrations
            assert(e.stopTimes(b)<e.calibrationTimes(b+1));
        end
    end
    idText=e.messages(startsWith(e.messages,'TRIALID '));
    ids=cellfun(@(text)sscanf(text,'TRIALID %d',1),idText);
    assert(isequal(ids(:)',1:numel(ids)) && numel(ids)<=40);
    assert(sum(startsWith(e.messages,'SESSION_START '))==double(e.starts>0));
    assert(sum(startsWith(e.messages,'SESSION_END '))==double(e.starts>0));
    complete=ismember(e.scenario,{'normal','mixed','boundaries'});
    if complete
        assert(strcmp(r.status,'complete') && r.summary.presented_trials==40 && r.summary.sync_count==4);
        assert(e.calibrations==4 && e.acceptances==4 && e.starts==4 && e.receives==1);
        assert(r.eyelink.transfer_verified && all(strcmp({r.blocks.status},'COMPLETE')));
        assert(numel(ids)==40 && sum(startsWith(e.messages,'TRIAL_RESULT '))==40);
        assert(sum(startsWith(e.messages,'BLOCK_START '))==4 && sum(startsWith(e.messages,'BLOCK_END '))==4);
        assert(sum(startsWith(e.messages,'TPAD_SYNC block='))==4);
        beginnings=find(startsWith(e.messages,'TRIALID ')); endings=find(startsWith(e.messages,'TRIAL_RESULT '));
        assert(all(endings>beginnings) && all(endings(1:39)<beginnings(2:40)));
        for t=1:40
            text=e.messages(beginnings(t):endings(t));
            assert(any(strcmp(text,sprintf('!V TRIAL_VAR block_number %d',ceil(t/10)))));
            assert(any(strcmp(text,sprintf('!V TRIAL_VAR trial_in_block %d',mod(t-1,10)+1))));
            assert(any(strcmp(text,sprintf('!V TRIAL_VAR global_trial %d',t))));
        end
        for b=1:4
            assert(e.acceptedTimes(b)<e.startTimes(b) && e.startTimes(b)+0.1<=e.syncTimes(b));
            assert(e.messageTimes(beginnings((b-1)*10+1))<e.startTimes(b));
            assert(r.sync(b).release_tpad_ms>r.sync(b).press_tpad_ms && r.sync(b).block_number==b);
            assert(contains(r.sync(b).eyelink_marker,sprintf('release_sequence=%d',r.sync(b).release_sequence)));
        end
        if strcmp(e.scenario,'mixed')
            assert(r.summary.correct==20 && r.summary.incorrect==4 && r.summary.timeouts==16);
            assert(r.summary.valid_optical_onsets==36 && r.summary.optical_artifact_pairs==8);
            assert(r.summary.mean_correct_rt_ms==522.5 && r.summary.mean_all_response_rt_ms==598);
            assert(all([r.trials(9:10:39).serial_grace_used]));
        else
            assert(r.summary.correct==40 && r.summary.valid_optical_pulses==40);
            assert(all([r.trials.rt_ms]==200));
        end
        if strcmp(e.scenario,'boundaries')
            between=r.messages([r.messages.acquisition_block]==0 & strcmp({r.messages.channel},'C'));
            assert(~isempty(between) && all([between.trial]==0));
            assert(any([r.messages.out_of_order]));
            assert(all(isfinite([r.trials.optical_off_ms])));
        end
    else
        if ismember(e.scenario,{'calibration_cancel','abort','abort_transfer','sync_abort'})
            assert(strcmp(r.status,'aborted'));
        else
            assert(strcmp(r.status,'error'));
        end
        if e.failBlock>0
            assert(all(strcmp({r.blocks(1:e.failBlock-1).status},'COMPLETE')));
            assert(~strcmp(r.blocks(e.failBlock).status,'COMPLETE'));
            assert(all(strcmp({r.blocks(e.failBlock+1:end).status},'NOT_PRESENTED')));
            assert(all(strcmp({r.trials(e.failBlock*10+1:end).outcome},'NOT_PRESENTED')));
        end
        if ismember(e.scenario,{'calibration_cancel','calibration_error','callback_error','start_error','sync_abort'})
            assert(r.summary.presented_trials==(e.failBlock-1)*10);
        end
        if ismember(e.scenario,{'transfer_interrupted','abort_transfer'})
            assert(~r.eyelink.transfer_verified && strcmp(char(read_bytes(r.eyelink.local_edf))','PARTIAL'));
            if strcmp(e.scenario,'abort_transfer')
                assert(strcmp(r.task_status,'aborted') && r.summary.presented_trials==22);
            else
                assert(strcmp(r.task_status,'complete') && r.summary.presented_trials==40 && numel(r.raw_messages)>=170);
            end
        end
    end
    assert_filter_queries(r,e,output);
end
fprintf('PASS: %d M5 four-block scenarios; synthetic hardware only.\n',size(cases,1));
end

function varargout = eye_dispatch(operation, varargin)
global M1_MOCK %#ok<GVMIS>
e = M1_MOCK.eye; scenario = e.scenario;
e.operations{end+1}=operation;
M1_MOCK.eye=e;
M1_MOCK.time=M1_MOCK.time+0.00005;
switch operation
    case 'Version', varargout={struct('version','3.0.19','module','Eyelink')};
    case 'EDKVersion', varargout={'2,1,762,0'};
    case 'IsConnected'
        result=double(e.connected);
        if e.connected && strcmp(scenario,'dummy'), result=-1; end
        varargout={result};
    case 'Initialize'
        M1_MOCK.eye.initializes=e.initializes+1;
        result=0;
        if strcmp(scenario,'connect_error'), result=-1;
        else, M1_MOCK.eye.connected=true; end
        varargout={result};
    case 'GetTrackerVersion', varargout={5,'EYELINK CL 5.15'};
    case 'ReadFromTracker'
        assert(~e.recording && e.opens==0 && ~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
        name=varargin{1}; number=1;
        if isfield(e.queryCounts,name), number=e.queryCounts.(name)+1; end
        M1_MOCK.eye.queryCounts.(name)=number;
        assert(number<=3,'Unbounded ReadFromTracker retries');
        reply='LEFT,RIGHT,GAZE,AREA,STATUS';
        sample=strcmp(name,'file_sample_data'); status=0;
        if ~sample, reply='LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE'; end
        if strcmp(scenario,'filters_disabled'), reply='LEFT,RIGHT'; end
        if ismember(scenario,{'real_host_filters','host_filter_whitespace'})
            replies={'AREA,BUTTON,GAZE,GAZERES,LEFT,RIGHT,STATUS,HMARKER,HMARKER,', ...
                'RIGHT, LEFT, BLINK, FIXATION, SACCADE, MESSAGE, BUTTON, INPUT,'};
            reply=replies{2-sample};
            if strcmp(scenario,'host_filter_whitespace'), reply=sprintf(' \t%s , \t',reply(1:end-1)); end
        elseif ismember(scenario,{'read_timeout','unverified_confirm','diagnostic_wrong_confirmation'})
            reply='';
        elseif sample
            switch scenario
                case 'first_empty'
                    if number==1, reply=''; end
                case 'third_valid'
                    reply="left right gaze area status";
                    if number<3, reply=''; end
                case {'sample_unverified','unverified_then_missing'}
                    reply='';
                case 'unusable_reply'
                    replies={sprintf(' \t '),{42},'UNREADABLE ???'}; reply=replies{number};
                case 'missing_after_empty'
                    reply='LEFT,RIGHT';
                    if number==1, reply=''; end
                case 'status_error'
                    status=-1;
                case 'status_error_after_empty'
                    status=-1;
                    if number==1, status=0; reply=''; end
                case 'query_exception'
                    error('Injected query exception');
                case 'disabled_none'
                    reply='NONE';
                case 'filter_malformed'
                    replies={'GAZE,,','LEFT,,GAZE',',GAZE'}; reply=replies{number};
                case 'filter_unknown'
                    reply='LEFT,RIGHT,GAZE,UNKNOWN,';
                case 'filter_missing'
                    reply='AREA,BUTTON,GAZERES,LEFT,RIGHT,STATUS,HMARKER,HMARKER,';
            end
        elseif ismember(scenario,{'event_missing','unverified_then_missing'})
            reply='LEFT,RIGHT';
        elseif strcmp(scenario,'event_first_empty') && number==1
            reply='';
        end
        varargout={status,reply};
    case 'OpenFile'
        assert(e.initializes==1 && e.connected && ~e.setup && ~M1_MOCK.displayOpen && ~M1_MOCK.serialOpen);
        assert(numel(varargin)==1,'Obsolete overwrite flag must never be used');
        assert(strcmp(varargin{1},[e.proposed '.edf']) && ~isempty(e.proposed));
        files=dir(fullfile(pwd,'data','numbered_circle_eyelink_*','eyelink_recovery.mat'));
        confirmed=false;
        for k=1:numel(files)
            saved=load(fullfile(files(k).folder,files(k).name));
            if strcmp(saved.eyelink.host_basename,e.proposed)
                confirmed=saved.eyelink.filename_confirmed;
                if isfield(e,'plannedBlocks'), M1_MOCK.eye.runFolder=files(k).folder; end
                if strcmp(scenario,'destination_exists')
                    fid=fopen(saved.eyelink.local_edf,'wb'); fwrite(fid,'KEEP'); fclose(fid);
                end
            end
        end
        assert(confirmed,'Filename mapping/confirmation was not persisted before OpenFile');
        M1_MOCK.eye.opens=e.opens+1; M1_MOCK.eye.open=true;
        varargout={double(strcmp(scenario,'openfile_error'))};
    case 'Command'
        assert(~e.recording,'Blocking command during recording');
        assert(startsWith(varargin{1},'add_file_preamble_text ') || startsWith(varargin{1},'screen_pixel_coords = '));
        varargout={0};
    case 'CalMessage', varargout={0,'VALIDATION RESULT: operator must judge quality'};
    case 'SetOfflineMode'
        M1_MOCK.eye.recording=false;
    case 'StartRecording'
        block=1;
        if isfield(e,'plannedBlocks')
            block=e.calibrations;
            assert(e.acceptances==block && numel(e.acceptedTimes)==block && isempty(e.hook));
            M1_MOCK.eye.startTimes(end+1)=M1_MOCK.time;
        end
        assert(e.open && e.accepted && e.starts==block-1);
        assert(M1_MOCK.serialOpen && M1_MOCK.mode5);
        assert(isequal([varargin{:}],[1 1 0 0]));
        assert(strcmp(e.messages{end},sprintf('TRIALID %d',(block-1)*10+1)));
        M1_MOCK.eye.starts=e.starts+1; M1_MOCK.eye.recording=true;
        M1_MOCK.eye.startTime=M1_MOCK.time;
        failed=strcmp(scenario,'start_error');
        if isfield(e,'plannedBlocks'), failed=failed && block==e.failBlock; end
        varargout={double(failed)};
    case 'CheckRecording'
        value=0;
        if strcmp(scenario,'recording_error') && M1_MOCK.onsets>=2, value=3; end
        if isfield(e,'plannedBlocks')
            value=0;
            if ismember(scenario,{'recording_error','tracker_disconnect'}) && ...
                    M1_MOCK.onsets>=(e.failBlock-1)*10+2
                value=3;
                if strcmp(scenario,'tracker_disconnect'), M1_MOCK.eye.connected=false; end
            end
        end
        varargout={value};
    case 'Message'
        assert(strcmp(varargin{1},'%s') && e.open);
        text=varargin{2};
        if strcmp(scenario,'message_error') && startsWith(text,'STIMULUS_ONSET ')
            varargout={1}; return;
        end
        slow=strcmp(scenario,'slow_message');
        if isfield(e,'plannedBlocks'), slow=slow && e.calibrations==e.failBlock; end
        if slow && startsWith(text,'STIMULUS_ONSET ')
            M1_MOCK.time=M1_MOCK.time+0.3;
        end
        M1_MOCK.eye.messages{end+1}=text;
        M1_MOCK.eye.messageTimes(end+1)=M1_MOCK.time;
        varargout={0};
    case 'StopRecording'
        assert(e.starts==e.stops+1);
        M1_MOCK.eye.stops=e.stops+1;
        failed=strcmp(scenario,'stop_error');
        if isfield(e,'plannedBlocks')
            failed=failed && e.calibrations==e.failBlock;
            M1_MOCK.eye.stopTimes(end+1)=M1_MOCK.time;
        end
        if failed, error('Injected EyeLink stop failure'); end
        M1_MOCK.eye.recording=false;
    case 'CloseFile'
        assert(e.open && e.closes==0);
        M1_MOCK.eye.closes=e.closes+1; M1_MOCK.eye.open=false;
        varargout={double(strcmp(scenario,'close_error'))};
    case 'ReceiveFile'
        assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
        assert(e.closes==1 && ~e.open && ~isfile(varargin{2}));
        parent=fileparts(varargin{2}); saved=load(fullfile(parent,'session.mat'));
        assert(isfield(saved.run,'trials'),'tPAD data must be saved before transfer');
        fid=fopen(varargin{2},'wb'); assert(fid>=0);
        if ismember(scenario,{'transfer_interrupted','abort_transfer'})
            fwrite(fid,'PARTIAL'); result=-1;
        else
            fwrite(fid,uint8(1:16)); result=16;
            if strcmp(scenario,'transfer_mismatch'), result=17; end
        end
        fclose(fid); M1_MOCK.eye.receives=e.receives+1; varargout={result};
    case 'Shutdown'
        assert(e.shutdowns==0); M1_MOCK.eye.shutdowns=e.shutdowns+1;
        M1_MOCK.eye.connected=false;
    otherwise
        error('Unexpected EyeLink operation: %s',operation);
end
end
