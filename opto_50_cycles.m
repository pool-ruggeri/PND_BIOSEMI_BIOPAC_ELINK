% Set the tPAD virtual COM port from Windows Device Manager.
comPort = 'COM5';
run_opto_cycles(fileparts(mfilename('fullpath')), comPort);

function run_opto_cycles(root, port)
run = m1_log('new', root, 'opto_50_cycles');
io = []; window = []; flips = [];
displayCleanup = onCleanup(@() m1_cleanup([]));
try
    previousSync = Screen('Preference', 'SkipSyncTests');
    syncCleanup = onCleanup(@() Screen('Preference', 'SkipSyncTests', previousSync));
    Screen('Preference', 'SkipSyncTests', 1);
    fprintf(2, ['WARNING: Visual synchronization tests are disabled (SkipSyncTests=1).\n' ...
        'Screen(''Flip'') timestamps are not yet scientifically qualified.\n']);
    screenNumber = max(Screen('Screens'));
    [window, ~, ifi] = m1_display(screenNumber); run.ifi_s = ifi;
    patch = m1_patch(window, screenNumber); run.patch = patch;
    Screen('FillRect', window, patch.black);
    Screen('Flip', window); % Establish black before opening the serial port.
    io = tpad_io('open', [], port, run.folder);
    serialCleanup = onCleanup(@() m1_cleanup(io, false));
    check_running(io);
    io = m1_wait(io, GetSecs + 0.5); % Stable black and setup-event settling.
    check_running(io);
    target = GetSecs + 2 * ifi;
    frames = max(1, round(0.5 / ifi));
    for transition = 1:100
        white = mod(transition, 2) == 1;
        Screen('FillRect', window, patch.black);
        edge = 'R';
        if white
            Screen('FillRect', window, patch.white, patch.rect); edge = 'P';
        end
        io = m1_wait(io, target - ifi); check_running(io);
        [vbl, onset, ended, missed] = Screen('Flip', window, target - ifi / 2);
        flips = [flips; struct('index', transition, 'trial', ceil(transition / 2), ...
            'phase', 'cycle', 'expected_edge', edge, 'scheduled_ptb', target, ...
            'vbl_ptb', vbl, 'onset_ptb', onset, 'flip_end_ptb', ended, ...
            'missed_s', missed)]; %#ok<AGROW>
        target = vbl + frames * ifi;
    end
    io = m1_wait(io, target); check_running(io); % Final black lasts 500 ms.
    run.status = 'complete';
catch problem
    run.error = getReport(problem, 'basic', 'hyperlinks', 'off');
    run.status = 'error';
    if ~isempty(io) && io.aborted, run.status = 'aborted'; end
end
% Blacken on abort; an emergency edge is not counted as a completed cycle.
if ~isempty(window) && (isempty(io) || isempty(io.failure))
    try
        if ismember(window, Screen('Windows'))
            Screen('FillRect', window, [0 0 0]); Screen('Flip', window);
        end
    catch
    end
end
if ~isempty(io)
    io = tpad_io('drain', io, 0.5);
    io = tpad_io('finish', io);
    if ~isempty(io.failure), run.status = 'error'; end
    run.raw_messages = io.messages; % Preserve records before optical postprocessing.
    [io.messages, run.matches, run.summary, run.optical_pulses] = m1_match_optical( ...
        io.messages, flips, 50, strcmp(run.status, 'complete'), 0.25, 50);
    io = tpad_io('close', io);
end
run.flips = flips;
m1_cleanup([]);
run = m1_log('save', run, io);
if isfield(run.summary, 'detected_on')
    s = run.summary;
    fprintf(['\nOPTICAL SENSOR TEST\nRAW ON/OFF: %d/%d; short artifact pairs: %d\n' ...
        'VALID ON/OFF matched: %d/%d (expected 50/50)\n' ...
        'Recovered intended pulses: %d; missing pulses: %d; hardware durations: %.0f..%.0f ms\n' ...
        'Intended pulse recovery: %s\n' ...
        'Missing: %d; duplicate: %d; unexpected: %d; out-of-order: %d\n' ...
        'Malformed: %d; state errors: %d; timing errors: %d; missed flips: %d\nFull checks: %s\n'], ...
        s.raw_detected_on, s.raw_detected_off, s.ignored_glitch_pairs, ...
        s.matched_on, s.matched_off, s.recovered_pulses, s.missing_pulses, ...
        s.duration_min_ms, s.duration_max_ms, s.pulse_recovery_result, ...
        s.missing_events, s.duplicate_events, ...
        s.unexpected_events, s.out_of_order_events, s.malformed_messages, ...
        s.state_errors, s.timing_errors, s.missed_flip_deadlines, s.result);
    if s.ignored_glitch_pairs > 0
        fprintf(2, 'WARNING: Raw optical artifacts remain (%d pairs); physical TTL cleanliness is unqualified.\n', ...
            s.ignored_glitch_pairs);
    end
    fprintf(['Result describes software reconstruction; physical sensor/TTL cleanliness\n' ...
        'requires separate qualification. Already emitted TTL pulses cannot be removed.\n']);
end
fprintf('Run status: %s\nSaved: %s\n', run.status, run.folder);
if ~isempty(run.error), fprintf(2, '%s\n', run.error); end
end

function check_running(io)
assert(isempty(io.failure), 'M1:Serial', ...
    'tPAD serial failure on %s: %s. Close the BBTK app or other port owner before retrying.', io.port, io.failure);
assert(~io.aborted, 'M1:Abort', 'ESC pressed; acquired data will be saved.');
end
