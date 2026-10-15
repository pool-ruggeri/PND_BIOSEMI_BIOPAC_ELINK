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
    'DrawFormattedText', 'input'};
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
reset_mock('calibration'); execute_script('opto_calibration');
saved = load(fullfile(project, 'opto_patch.mat'));
assert(numel(saved.patch.rect) == 4 && isequal(saved.patch.resolution, [1920 1080]));
assert(~M1_MOCK.displayOpen);
reset_mock('cycles'); execute_script('opto_50_cycles');
r = latest_run(project, 'opto_50_cycles');
assert(strcmp(r.status, 'complete') && strcmp(r.summary.result, 'PASS'));
assert(r.summary.detected_on == 50 && r.summary.detected_off == 50);
assert(numel(r.flips) == 100 && ~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
assert(isequal(M1_MOCK.commands, {'X', sprintf('MOD5\r\n')}));
reset_mock('cycles_silent'); execute_script('opto_50_cycles');
r = latest_run(project, 'opto_50_cycles');
assert(strcmp(r.summary.result, 'FAIL') && r.summary.missing_events == 100);
assert(r.summary.detected_on == 0 && r.summary.detected_off == 0);
reset_mock('cycles_abort'); execute_script('opto_50_cycles');
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
reset_mock('task_missing_onset'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'complete') && isnan(r.trials(3).rt_ms));
assert(strcmp(r.trials(3).response_validity, 'unverified_missing_optical_onset'));
reset_mock('task_abort_sync'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'aborted') && isfinite(r.sync.press_tpad_ms));
assert(isnan(r.sync.release_tpad_ms) && r.summary.presented_trials == 0);
assert(r.summary.event_issues == 0 && r.summary.unavailable_rt == 0);
reset_mock('task_disconnect'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'error') && contains(r.serial_failure, 'Injected'));
assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
saved.patch.rect = [900 480 1045 624]; patch = saved.patch;
save(fullfile(project, 'opto_patch.mat'), 'patch');
reset_mock('task_bad_patch'); execute_script('simple_task');
r = latest_run(project, 'simple_task');
assert(strcmp(r.status, 'error') && contains(r.error, 'central stimulus'));
assert(~M1_MOCK.serialOpen && ~M1_MOCK.displayOpen);
fprintf('PASS: 9 simulated script scenarios. No physical hardware validation.\n');
end

function execute_script(name)
eval(name); % Execute the real script copy with its own local functions.
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
M1_MOCK = struct('dispatch', @dispatch, 'scenario', scenario, 'time', 0, ...
    'displayOpen', false, 'serialOpen', false, 'mode5', false, ...
    'draftWhite', false, 'white', false, 'draftSync', false, 'syncSent', false, ...
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
        M1_MOCK.inputs = M1_MOCK.inputs + 1;
        dims = [53.1 29.9]; varargout = {dims(M1_MOCK.inputs)};
    case 'KbName'
        keys = {'ESCAPE', 'space', 'RightArrow', 'LeftArrow', 'DownArrow', 'UpArrow'};
        if strcmp(varargin{1}, 'UnifyKeyNames'), return; end
        varargout = {find(strcmp(keys, varargin{1}))};
    case 'KbCheck'
        keys = false(1, 256);
        if strcmp(s, 'calibration')
            keys(1) = M1_MOCK.flips >= 4;
            keys(3) = M1_MOCK.flips == 1; keys(2) = M1_MOCK.flips == 2;
        elseif strcmp(s, 'cycles_abort')
            keys(1) = M1_MOCK.time > 3;
        elseif strcmp(s, 'task_abort_sync')
            keys(1) = M1_MOCK.syncSent && M1_MOCK.time > 0.72;
        end
        varargout = {any(keys), M1_MOCK.time, keys};
    case 'DrawFormattedText'
        M1_MOCK.draftSync = true;
    case 'Screen'
        switch varargin{1}
            case 'Screens', varargout = {0};
            case 'OpenWindow'
                M1_MOCK.displayOpen = true; varargout = {1, [0 0 1920 1080]};
            case 'GetFlipInterval', varargout = {1/60};
            case 'FillRect'
                M1_MOCK.draftWhite = any(varargin{3} > 0);
            case 'Flip'
                earliest = M1_MOCK.time;
                if numel(varargin) >= 3, earliest = max(earliest, varargin{3}); end
                vbl = (floor(earliest * 60 + 1e-8) + 1) / 60;
                M1_MOCK.time = vbl + 0.0001; M1_MOCK.flips = M1_MOCK.flips + 1;
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
