function run_script_smoke_tests
%RUN_SCRIPT_SMOKE_TESTS Execute copies of the scripts with isolated PTB stubs.
% Synthetic events exercise software flow only. No hardware is opened.
root = fileparts(fileparts(mfilename('fullpath')));
work = tempname(fullfile(root, '.local', 'script_smoke'));
project = fullfile(work, 'project'); stubs = fullfile(work, 'stubs');
if ~isfolder(project), mkdir(project); end
if ~isfolder(stubs), mkdir(stubs); end
files = dir(fullfile(root, '*.m'));
for k = 1:numel(files), copyfile(fullfile(root, files(k).name), project); end
names = {'Screen', 'IOPort', 'GetSecs', 'WaitSecs', 'KbCheck', 'KbName', ...
    'AssertOpenGL', 'ListenChar', 'HideCursor', 'ShowCursor', 'Priority', ...
    'DrawFormattedText', 'GetMouse', 'kPsychGUIWindow', 'input'};
for k = 1:numel(names)
    fid = fopen(fullfile(stubs, [names{k} '.m']), 'w');
    assert(fid >= 0);
    fprintf(fid, ['function varargout = %s(varargin)\n' ...
        'global M1_MOCK\n[varargout{1:nargout}] = M1_MOCK.dispatch(''%s'',varargin{:});\nend\n'], ...
        names{k}, names{k});
    fclose(fid);
end
oldPath = path; oldFolder = pwd;
cleanup = onCleanup(@() restore(oldPath, oldFolder));
addpath(stubs, '-begin'); cd(project);
global M1_MOCK %#ok<GVMIS> Shared by the isolated generated wrappers only.
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
assert(isequal(r.patch, saved.patch));
assert(all(arrayfun(@(f) isequal(f.rect, saved.patch.rect), ...
    M1_MOCK.history([M1_MOCK.history.white]))));
assert(all(arrayfun(@(f) isequal(f.rect + repmat(f.origin, 1, 2), saved.patch.desktop_rect), ...
    M1_MOCK.history([M1_MOCK.history.white]))));
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
assert(isequal(r.patch, saved.patch));
assert(all(arrayfun(@(f) isequal(f.rect, saved.patch.rect), ...
    M1_MOCK.history([M1_MOCK.history.white]))));
assert(all(arrayfun(@(f) isequal(f.rect + repmat(f.origin, 1, 2), saved.patch.desktop_rect), ...
    M1_MOCK.history([M1_MOCK.history.white]))));
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
saved.patch.rect = [900 480 1045 624]; patch = saved.patch;
save(fullfile(project, 'opto_patch.mat'), 'patch');
reset_mock('task_bad_patch'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'error') && contains(r.error, 'central stimulus'));
assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
fprintf('PASS: 14 simulated script scenarios, including sync preference restoration on completion, abort, and errors.\n');
fprintf('No physical GUI/hardware validation.\n');
end

function bytes = read_bytes(file)
fid = fopen(file, 'rb');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
end

function execute_script(name)
global M1_MOCK %#ok<GVMIS>
previousSync = M1_MOCK.preferences.SkipSyncTests;
output = evalc(name); % Execute the real script copy with its own local functions.
fprintf('%s', output);
assert(M1_MOCK.preferences.SkipSyncTests == previousSync, 'SkipSyncTests was not restored.');
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
    'history', struct('rect', {}, 'white', {}, 'origin', {}), ...
    'preferences', struct('WindowShieldingLevel', 2000, 'SkipSyncTests', 0), ...
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
    case 'GetSecs'
        assert(M1_MOCK.time < 100, 'Mock time limit exceeded.');
        varargout = {M1_MOCK.time};
    case 'WaitSecs'
        M1_MOCK.time = M1_MOCK.time + varargin{end};
    case 'input'
        error('Calibration must not prompt for input.');
    case 'kPsychGUIWindow'
        varargout = {32};
    case 'KbName'
        keys = repmat({[]}, 1, 256); % PTB leaves unnamed entries as numeric [].
        keys(1:11) = {'ESCAPE', 'space', 'RightArrow', 'LeftArrow', 'DownArrow', 'UpArrow', ...
            'Return', '=+', '-_', '+', '-'};
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
        M1_MOCK.draftSync = true;
    case 'Screen'
        switch varargin{1}
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
            case 'FillRect'
                M1_MOCK.draftWhite = any(varargin{3} > 0);
                M1_MOCK.draftRect = [];
                if numel(varargin) >= 4, M1_MOCK.draftRect = varargin{4}; end
            case 'Flip'
                earliest = M1_MOCK.time;
                if numel(varargin) >= 3, earliest = max(earliest, varargin{3}); end
                vbl = (floor(earliest * 60 + 1e-8) + 1) / 60;
                M1_MOCK.time = vbl + 0.0001; M1_MOCK.flips = M1_MOCK.flips + 1;
                M1_MOCK.history(end + 1) = struct('rect', M1_MOCK.draftRect, ...
                    'white', M1_MOCK.draftWhite, 'origin', M1_MOCK.windowGlobal(1:2));
                if M1_MOCK.mode5 && M1_MOCK.draftWhite ~= M1_MOCK.white
                    edge = 'R';
                    if M1_MOCK.draftWhite
                        edge = 'P'; M1_MOCK.onsets = M1_MOCK.onsets + 1;
                    end
                    missing = strcmp(s, 'task_missing_onset') && ...
                        M1_MOCK.onsets == 3 && edge == 'P';
                    if ~strcmp(s, 'cycles_silent') && ~missing
                        queue_event(vbl + 0.004, sprintf('C %s 1 %d', edge, stamp(vbl)));
                    end
                    if startsWith(s, 'task') && edge == 'P'
                        queue_event(vbl + 0.254, sprintf('A P 1 %d', stamp(vbl + 0.25)));
                        queue_event(vbl + 0.904, sprintf('A R 1 %d', stamp(vbl + 0.9)));
                    end
                end
                M1_MOCK.white = M1_MOCK.draftWhite;
                if M1_MOCK.draftSync && ~M1_MOCK.syncSent
                    M1_MOCK.syncSent = true;
                    queue_event(vbl + 0.104, sprintf('A P 1 %d', stamp(vbl + 0.1)));
                    queue_event(vbl + 0.204, sprintf('A R 1 %d', stamp(vbl + 0.2)));
                end
                varargout = {vbl, vbl, M1_MOCK.time, -0.001};
            case 'CloseAll', M1_MOCK.displayOpen = false;
        end
    case 'IOPort'
        switch varargin{1}
            case 'OpenSerialPort'
                M1_MOCK.serialOpen = true; varargout = {71, ''};
            case 'Write'
                text = char(varargin{3}); M1_MOCK.commands{end + 1} = text;
                if strcmp(text, 'X')
                    M1_MOCK.mode5 = false; queue_event(M1_MOCK.time, 'MODE 0:');
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
                elseif ~isempty(M1_MOCK.queue) && M1_MOCK.queue(1).ready <= M1_MOCK.time
                    n = min(3, numel(M1_MOCK.queue(1).bytes));
                    bytes = M1_MOCK.queue(1).bytes(1:n);
                    M1_MOCK.queue(1).bytes(1:n) = [];
                    if isempty(M1_MOCK.queue(1).bytes), M1_MOCK.queue(1) = []; end
                end
                varargout = {bytes, M1_MOCK.time, err};
            case 'Close', M1_MOCK.serialOpen = false;
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
