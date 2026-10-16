% Set the tPAD virtual COM port from Windows Device Manager.
comPort = 'COM5';
run_simple_task(fileparts(mfilename('fullpath')), comPort);

function run_simple_task(root, port)
run = m1_log('new', root, 'simple_task');
io = []; window = []; flips = []; matches = []; stimulusWhite = false; currentTrial = 0;
record = struct('fixation_ptb', NaN, 'onset_ptb', NaN, 'offset_ptb', NaN, ...
    'response_deadline_ptb', NaN, 'window_completed', false);
records = repmat(record, 10, 1);
displayCleanup = onCleanup(@() m1_cleanup([]));
try
    previousSync = Screen('Preference', 'SkipSyncTests');
    syncCleanup = onCleanup(@() Screen('Preference', 'SkipSyncTests', previousSync));
    Screen('Preference', 'SkipSyncTests', 1);
    fprintf(2, ['WARNING: Visual synchronization tests are disabled (SkipSyncTests=1).\n' ...
        'Screen(''Flip'') timestamps are not yet scientifically qualified.\n']);
    screenNumber = max(Screen('Screens'));
    [window, rect, ifi] = m1_display(screenNumber); run.ifi_s = ifi;
    patch = m1_patch(window, screenNumber); run.patch = patch;
    center = rect(3:4) / 2;
    Screen('FillRect', window, patch.black); Screen('Flip', window);
    io = tpad_io('open', [], port, run.folder);
    serialCleanup = onCleanup(@() m1_cleanup(io, false));
    check_running(io);
    io = m1_wait(io, GetSecs + 0.5); check_running(io);
    Screen('FillRect', window, patch.black);
    DrawFormattedText(window, ...
        'Press Button 1 to synchronize the recording systems.', ...
        'center', 'center', patch.white);
    Screen('FillRect', window, patch.black, patch.rect);
    f = flip_record(window, NaN, 0, 'sync_screen', '', numel(flips) + 1);
    flips = [flips; f];
    cursor = numel(io.messages); syncPress = NaN; syncRelease = NaN;
    while ~isfinite(syncRelease)
        io = m1_wait(io, GetSecs + 0.001); check_running(io);
        for j = cursor + 1:numel(io.messages)
            m = io.messages(j);
            if ~strcmp(m.kind, 'event') || m.channel ~= 'A' || m.sensor ~= 1 || ...
                    m.duplicate || m.out_of_order || m.state_error, continue; end
            if ~isfinite(syncPress) && m.edge == 'P' && m.rx_first_ptb >= f.onset_ptb
                syncPress = j; io.messages(j).label = 'SYNC_BUTTON_PRESS';
                run.sync = struct('press_sequence', m.sequence, ...
                    'press_tpad_ms', m.tpad_ms, 'release_sequence', NaN, ...
                    'release_tpad_ms', NaN);
            elseif isfinite(syncPress) && ~isfinite(syncRelease) && m.edge == 'R' && ...
                    m.tpad_ms >= io.messages(syncPress).tpad_ms
                syncRelease = j; io.messages(j).label = 'SYNC_BUTTON_RELEASE';
            end
        end
        cursor = numel(io.messages);
    end
    run.sync = struct('press_sequence', io.messages(syncPress).sequence, ...
        'press_tpad_ms', io.messages(syncPress).tpad_ms, ...
        'release_sequence', io.messages(syncRelease).sequence, ...
        'release_tpad_ms', io.messages(syncRelease).tpad_ms);
    fprintf('SYNC_BUTTON_PRESS: %.0f tPAD ms. Starting 10 trials.\n', run.sync.press_tpad_ms);
    % Mark all earlier button presses so they cannot be used as responses.
    for j = 1:syncRelease
        if isempty(io.messages(j).label) && strcmp(io.messages(j).channel, 'A')
            io.messages(j).label = 'PRE_TRIAL_BUTTON_EVENT';
        end
    end
    fixationFrames = max(1, round(1.0 / ifi));
    stimulusFrames = max(1, round(0.5 / ifi));
    for t = 1:10
        currentTrial = t;
        draw_frame(window, patch, center, 'fixation');
        f = flip_record(window, NaN, t, 'fixation', '', numel(flips) + 1);
        flips = [flips; f]; records(t).fixation_ptb = f.onset_ptb; %#ok<AGROW>
        target = f.vbl_ptb + fixationFrames * ifi;
        draw_frame(window, patch, center, 'stimulus');
        io = m1_wait(io, target - ifi); check_running(io);
        f = flip_record(window, target, t, 'stimulus_on', 'P', numel(flips) + 1, ifi);
        stimulusWhite = true;
        flips = [flips; f]; records(t).onset_ptb = f.onset_ptb; %#ok<AGROW>
        records(t).response_deadline_ptb = f.onset_ptb + 1.5;
        target = f.vbl_ptb + stimulusFrames * ifi;
        draw_frame(window, patch, center, 'blank');
        io = m1_wait(io, target - ifi); check_running(io);
        f = flip_record(window, target, t, 'stimulus_off', 'R', numel(flips) + 1, ifi);
        stimulusWhite = false;
        flips = [flips; f]; records(t).offset_ptb = f.onset_ptb; %#ok<AGROW>
        io = m1_wait(io, records(t).response_deadline_ptb); check_running(io);
        records(t).window_completed = true;
        % The screen is already black; acquisition continues throughout ITI.
        io = m1_wait(io, records(t).response_deadline_ptb + 0.5); check_running(io);
    end
    run.status = 'complete';
catch problem
    run.error = getReport(problem, 'basic', 'hyperlinks', 'off');
    run.status = 'error';
    if ~isempty(io) && io.aborted, run.status = 'aborted'; end
end
if ~isempty(window) && (isempty(io) || isempty(io.failure))
    try
        if ismember(window, Screen('Windows'))
            Screen('FillRect', window, [0 0 0]);
            edge = ''; if stimulusWhite, edge = 'R'; end
            f = flip_record(window, NaN, currentTrial, 'cleanup_black', edge, numel(flips) + 1);
            flips = [flips; f];
            if stimulusWhite, records(currentTrial).offset_ptb = f.onset_ptb; end
        end
    catch
        % Keep the original failure; the cleanup guard still closes display.
    end
end
if ~isempty(io)
    io = tpad_io('drain', io, 0.5); io = tpad_io('finish', io);
    if ~isempty(io.failure), run.status = 'error'; end
    if ~isempty(flips)
        [io.messages, matches] = m1_match_optical(io.messages, flips, 10, ...
            strcmp(run.status, 'complete'), 0.25, 50);
    end
    [io.messages, run.trials] = m1_trials(io.messages, records, matches);
    io = tpad_io('close', io);
else
    [~, run.trials] = m1_trials([], records, matches);
end
run.flips = flips; run.matches = matches; run.trial_boundaries = records;
presented = isfinite([records.onset_ptb]);
run.summary = struct('planned_trials', 10, 'presented_trials', sum(isfinite([records.onset_ptb])), ...
    'valid_responses', sum(strcmp({run.trials.response_validity}, 'valid')), ...
    'unavailable_rt', sum(presented & ~isfinite([run.trials.rt_ms])), ...
    'missing_optical_on', sum(presented & [run.trials.missing_optical_on]), ...
    'missing_optical_off', sum(presented & [run.trials.missing_optical_off]), ...
    'missing_responses', sum(presented & [records.window_completed] & ...
        ismember({run.trials.response_validity}, {'missing_response', 'missing_onset_and_response'})), ...
    'premature_presses', sum([run.trials.premature_presses]), ...
    'extra_presses', sum([run.trials.extra_presses]), ...
    'event_issues', sum([run.trials.event_issues]));
m1_cleanup([]);
run = m1_log('save', run, io);
fprintf(['\nSIMPLE TASK: %s\nPresented: %d/10; valid responses: %d; RT unavailable: %d\n' ...
    'Missing optical ON/OFF: %d/%d; premature presses: %d; event issues: %d\nSaved: %s\n'], ...
    run.status, run.summary.presented_trials, run.summary.valid_responses, ...
    run.summary.unavailable_rt, run.summary.missing_optical_on, ...
    run.summary.missing_optical_off, run.summary.premature_presses, ...
    run.summary.event_issues, run.folder);
if ~isempty(run.error), fprintf(2, '%s\n', run.error); end
end

function draw_frame(window, patch, center, phase)
Screen('FillRect', window, patch.black);
if strcmp(phase, 'fixation')
    Screen('DrawLines', window, [-12 12 0 0; 0 0 -12 12], 3, patch.white, center);
elseif strcmp(phase, 'stimulus')
    Screen('FillOval', window, patch.white, [center - 40 center + 40]);
end
color = patch.black;
if strcmp(phase, 'stimulus'), color = patch.white; end
Screen('FillRect', window, color, patch.rect);
end

function f = flip_record(window, target, trial, phase, edge, index, ifi)
when = 0;
if nargin == 7 && isfinite(target), when = target - ifi / 2; end
[vbl, onset, ended, missed] = Screen('Flip', window, when);
f = struct('index', index, 'trial', trial, 'phase', phase, 'expected_edge', edge, ...
    'scheduled_ptb', target, 'vbl_ptb', vbl, 'onset_ptb', onset, ...
    'flip_end_ptb', ended, 'missed_s', missed);
end

function check_running(io)
assert(isempty(io.failure), 'M1:Serial', ...
    'tPAD serial failure on %s: %s. Close the BBTK app or other port owner before retrying.', io.port, io.failure);
assert(~io.aborted, 'M1:Abort', 'ESC pressed; acquired data will be saved.');
end
