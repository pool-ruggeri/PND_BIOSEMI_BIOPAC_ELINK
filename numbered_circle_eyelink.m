% Set the tPAD virtual COM port from Windows Device Manager.
comPort = 'COM5';
run_eyelink_circles(fileparts(mfilename('fullpath')), comPort);

function run_eyelink_circles(root, port)
run = m1_log('new', root, 'numbered_circle_eyelink');
eye = m3_eyelink(run.folder, root);
eyeCleanup = onCleanup(@() eye.release());
run.targets = [1 2 3 4 1 2 3 4 1 2];
run.serial_grace_s = 0.100; % Receive delayed bytes; never extend hardware RT >1500 ms.
io = []; window = []; flips = []; matches = []; white = false; currentTrial = 0;
record = struct('fixation_ptb', NaN, 'onset_ptb', NaN, 'offset_ptb', NaN, ...
    'response_deadline_ptb', NaN, 'grace_deadline_ptb', NaN, ...
    'response_close_ptb', NaN, 'iti_start_ptb', NaN, 'start_sequence', 0, ...
    'expected_button', NaN, 'online_response_sequence', NaN, ...
    'online_button', NaN, 'online_button_ms', NaN, 'online_correct', NaN, 'online_received_ptb', NaN, ...
    'online_processed_ptb', NaN, 'online_anchor_available', false, ...
    'window_completed', false);
records = repmat(record, 10, 1);
displayCleanup = [];
fprintf(2, ['WARNING: Visual synchronization tests are disabled (SkipSyncTests=1).\n' ...
    'Screen(''Flip'') timestamps are not yet scientifically qualified.\n']);
try
    eye.initialize();
    previousSync = Screen('Preference', 'SkipSyncTests');
    syncCleanup = onCleanup(@() Screen('Preference', 'SkipSyncTests', previousSync));
    Screen('Preference', 'SkipSyncTests', 1);
    screen = max(Screen('Screens'));
    displayCleanup = onCleanup(@() m1_cleanup([]));
    [window, rect, ifi] = m1_display(screen); patch = m1_patch(window, screen);
    run.patch = patch; run.ifi_s = ifi; center = rect(3:4) / 2;
    Screen('FillRect', window, patch.black); Screen('Flip', window);
    eye.calibrate(window, patch);
    io = tpad_io('open', [], port, run.folder);
    serialCleanup = onCleanup(@() m1_cleanup(io, false));
    check_running(io);
    io = m1_wait(io, GetSecs + 0.5); check_running(io);
    io = eye_work(eye, io, 'message', 'TRIALID 1'); check_running(io);
    io = eye_work(eye, io, 'start', ''); check_running(io);
    io = m1_wait(io, GetSecs + 0.1); check_running(io);
    io = eye_work(eye, io, 'check', ''); check_running(io);
    estate = eye.state();
    io = eye_work(eye, io, 'message', ['SESSION_START run_id=' estate.run_id]); check_running(io);
    lastHealth = GetSecs;
    Screen('FillRect', window, patch.black);
    DrawFormattedText(window, 'Press Button 1 to synchronize the recording systems.', ...
        'center', 'center', patch.white);
    Screen('FillRect', window, patch.black, patch.rect);
    f = flip_record(window, NaN, 0, 'sync_screen', '', 1, ifi); flips = [flips; f];
    cursor = numel(io.messages); press = NaN; syncMarked = false;
    run.sync = struct('press_sequence', NaN, 'press_tpad_ms', NaN, ...
        'release_sequence', NaN, 'release_tpad_ms', NaN);
    while ~isfinite(run.sync.release_sequence)
        io = m1_wait(io, GetSecs + 0.001); check_running(io);
        for j = cursor + 1:numel(io.messages)
            m = io.messages(j);
            if ~strcmp(m.kind, 'event') || ~strcmp(m.channel, 'A') || m.sensor ~= 1 || ...
                    m.duplicate || m.out_of_order || m.state_error, continue; end
            if ~isfinite(press) && m.edge == 'P' && m.rx_first_ptb >= f.onset_ptb
                press = j; io.messages(j).label = 'SYNC_BUTTON_PRESS';
                run.sync.press_sequence = m.sequence; run.sync.press_tpad_ms = m.tpad_ms;
            elseif isfinite(press) && m.edge == 'R' && m.tpad_ms >= run.sync.press_tpad_ms
                io.messages(j).label = 'SYNC_BUTTON_RELEASE';
                run.sync.release_sequence = m.sequence; run.sync.release_tpad_ms = m.tpad_ms;
            end
        end
        cursor = numel(io.messages);
        if isfinite(run.sync.press_tpad_ms) && ~syncMarked
            io = eye_work(eye, io, 'message', sprintf('TPAD_SYNC tpad_ms=%.0f sequence=%d', ...
                run.sync.press_tpad_ms, run.sync.press_sequence));
            syncMarked = true; check_running(io);
        end
        if GetSecs - lastHealth >= 0.1
            io = eye_work(eye, io, 'check', ''); check_running(io); lastHealth = GetSecs;
        end
    end
    fprintf('SYNC_BUTTON_PRESS: %.0f tPAD ms. Respond with the button matching each digit.\n', ...
        run.sync.press_tpad_ms);
    Screen('TextSize', window, 48);
    fixationFrames = max(1, round(1.0 / ifi));
    stimulusFrames = max(1, round(0.5 / ifi));
    for t = 1:10
        if t > 1
            io = eye_work(eye, io, 'message', sprintf('TRIALID %d', t)); check_running(io);
        end
        currentTrial = t;
        records(t).expected_button = run.targets(t);
        draw_frame(window, patch, center, 'fixation', run.targets(t));
        f = flip_record(window, NaN, t, 'fixation', '', numel(flips) + 1, ifi);
        flips = [flips; f]; records(t).fixation_ptb = f.onset_ptb; %#ok<AGROW>
        target = f.vbl_ptb + fixationFrames * ifi;
        draw_frame(window, patch, center, 'stimulus', run.targets(t));
        io = m1_wait(io, target - ifi); check_running(io);
        if ~isempty(io.messages), records(t).start_sequence = io.messages(end).sequence; end
        f = flip_record(window, target, t, 'stimulus_on', 'P', numel(flips) + 1, ifi);
        white = true; flips = [flips; f]; %#ok<AGROW>
        records(t).onset_ptb = f.onset_ptb;
        records(t).response_deadline_ptb = f.onset_ptb + 1.5;
        records(t).grace_deadline_ptb = records(t).response_deadline_ptb + run.serial_grace_s;
        target = f.vbl_ptb + stimulusFrames * ifi;
        io = eye_work(eye, io, 'message', sprintf('STIMULUS_ONSET trial=%d digit=%d flip_ptb=%.9f', ...
            t, run.targets(t), f.onset_ptb)); check_running(io);
        draw_frame(window, patch, center, 'blank', run.targets(t));
        % Latch serial input immediately, but always finish the 500 ms stimulus.
        [io, records(t)] = listen(io, records(t), flips, t, target - ifi, false, eye); check_running(io);
        f = flip_record(window, target, t, 'stimulus_off', 'R', numel(flips) + 1, ifi);
        white = false; flips = [flips; f]; records(t).offset_ptb = f.onset_ptb; %#ok<AGROW>
        io = eye_work(eye, io, 'message', sprintf('STIMULUS_OFFSET trial=%d flip_ptb=%.9f', t, f.onset_ptb));
        check_running(io);
        [io, records(t)] = listen(io, records(t), flips, t, records(t).grace_deadline_ptb, true, eye); check_running(io);
        records(t).response_close_ptb = GetSecs;
        records(t).window_completed = GetSecs >= records(t).response_deadline_ptb;
        records(t).iti_start_ptb = GetSecs;
        itiEnd = records(t).iti_start_ptb + 0.5;
        io = eye_work(eye, io, 'check', ''); check_running(io);
        io = trial_snapshot(eye, io, records, flips, run.targets, t, itiEnd); check_running(io);
        assert(GetSecs < itiEnd, 'M3:Timing', 'EyeLink work overran the fixed 500 ms ITI.');
        io = m1_wait(io, itiEnd); check_running(io);
    end
    run.status = 'complete';
catch problem
    run.error = getReport(problem, 'basic', 'hyperlinks', 'off'); run.status = 'error';
    if (~isempty(io) && io.aborted) || strcmp(problem.identifier, 'M3:Abort'), run.status = 'aborted'; end
    if startsWith(problem.identifier, 'M3:'), eye.fail(problem); end
    if currentTrial > 0 && ~isfinite(records(currentTrial).response_close_ptb)
        records(currentTrial).response_close_ptb = GetSecs;
    end
end
if ~isempty(window) && (isempty(io) || isempty(io.failure))
    try
        if ismember(window, Screen('Windows'))
            Screen('FillRect', window, [0 0 0]);
            edge = ''; if white, edge = 'R'; end
            f = flip_record(window, NaN, currentTrial, 'cleanup_black', edge, numel(flips) + 1, ifi);
            flips = [flips; f];
            if white, records(currentTrial).offset_ptb = f.onset_ptb; end
        end
    catch
    end
end
if ~isempty(io)
    io = tpad_io('drain', io, 0.5); io = tpad_io('finish', io);
    if ~isempty(io.failure) && ~io.aborted, run.status = 'error'; end
    run.raw_messages = io.messages;
    [io.messages, matches, optical, run.optical_pulses] = m1_match_optical( ...
        io.messages, flips, 10, strcmp(run.status, 'complete'), 0.25, 50);
    run.optical_summary = struct('raw_on', optical.raw_detected_on, 'raw_off', optical.raw_detected_off, ...
        'matched_on', optical.matched_on, 'matched_off', optical.matched_off, ...
        'artifact_pairs', optical.ignored_glitch_pairs, 'missing_events', optical.missing_events);
    [io.messages, run.trials] = m2_trials(io.messages, records, matches, run.targets);
    io = tpad_io('close', io);
else
    [~, run.trials] = m2_trials([], records, matches, run.targets);
end
run.flips = flips; run.matches = matches; run.trial_boundaries = records;
presented = isfinite([run.trials.stimulus_flip_ptb]);
responded = ismember({run.trials.outcome}, {'CORRECT', 'INCORRECT'});
correct = strcmp({run.trials.outcome}, 'CORRECT');
sync = ~isempty(run.sync) && isfinite(run.sync.press_tpad_ms);
run.summary = struct('planned_trials', 10, 'presented_trials', sum(presented), ...
    'correct', sum(correct), 'incorrect', sum(strcmp({run.trials.outcome}, 'INCORRECT')), ...
    'timeouts', sum(strcmp({run.trials.outcome}, 'TIMEOUT')), ...
    'valid_optical_onsets', sum(presented & ~[run.trials.missing_optical_on]), ...
    'valid_optical_offsets', sum(presented & ~[run.trials.missing_optical_off]), ...
    'optical_artifact_pairs', sum([run.trials.optical_artifact_pairs]), ...
    'sync_recorded', sync, 'mean_correct_rt_ms', mean([run.trials(correct).rt_ms], 'omitnan'), ...
    'mean_all_response_rt_ms', mean([run.trials(responded).rt_ms], 'omitnan'));
if ~isempty(displayCleanup), m1_cleanup([]); end
run.eyelink = eye.state();
% Preserve tPAD results before potentially blocking EDF finalization/transfer.
try
    run = m1_log('save', run, io);
catch problem
    eye.fail(problem); run.error = problem.message; run.status = 'error';
end
eye.finish(run.status); run.eyelink = eye.state(); run.task_status = run.status;
if ~isempty(run.eyelink.failure) && strcmp(run.status, 'complete')
    run.status = 'error'; run.error = run.eyelink.failure;
end
run = m1_log('save', run, io);
if ~isempty(run.sync)
    writetable(struct2table(run.sync, 'AsArray', true), fullfile(run.folder, 'sync.csv'));
end
s = run.summary; syncText = 'NO'; if sync, syncText = 'YES'; end
fprintf(['\nNUMBERED CIRCLE EYELINK TASK\nTrials presented: %d\nCorrect responses: %d\n' ...
    'Incorrect responses: %d\nTimeouts: %d\nValid optical onsets: %d/10\n' ...
    'Valid optical offsets: %d/10\nOptical artifact pairs: %d\nSYNC recorded: %s\n' ...
    'Mean correct RT: %.1f ms\nMean all-response RT: %.1f ms\nRun status: %s\nSaved: %s\n'], ...
    s.presented_trials, s.correct, s.incorrect, s.timeouts, s.valid_optical_onsets, ...
    s.valid_optical_offsets, s.optical_artifact_pairs, syncText, ...
    s.mean_correct_rt_ms, s.mean_all_response_rt_ms, upper(run.status), run.folder);
fprintf('Host EDF: %s | Transfer verified: %d | Recovery: %s\n', ...
    run.eyelink.host_edf, run.eyelink.transfer_verified, fullfile(run.folder, 'eyelink_recovery.mat'));
if ~isempty(run.eyelink.failure) && ~contains(run.error, run.eyelink.failure)
    fprintf(2, 'EyeLink: %s\n', run.eyelink.failure);
end
if ~isempty(run.error), fprintf(2, '%s\n', run.error); end

    function check_running(io)
        assert(isempty(io.failure), 'M1:Serial', ...
            'tPAD serial failure on %s: %s. Close the BBTK app or other port owner before retrying.', io.port, io.failure);
        assert(~io.aborted, 'M1:Abort', 'ESC pressed; acquired data will be saved.');
        estate = eye.state(); assert(isempty(estate.failure), 'M3:EyeLink', '%s', estate.failure);
    end

end

function [io, r] = listen(io, r, flips, trial, deadline, advance, eye)
lastCount = -1;
while true
    io = m1_wait(io, min(deadline, GetSecs + 0.001));
    if ~isempty(io.failure) || io.aborted, return; end % Return acquired state before throwing.
    if numel(io.messages) ~= lastCount
        analyzedCount = numel(io.messages);
        % Analyze a copy; incomplete optical pairs never block serial control.
        [~, matches] = m1_match_optical(io.messages, flips, 10, false, 0.25, 50);
        on = matches([matches.trial] == trial & strcmp({matches.edge}, 'P'));
        onsetMs = NaN; sequence = NaN;
        if numel(on) == 1, onsetMs = on.tpad_ms; sequence = on.event_sequence; end
        [j, verified] = m2_response(io.messages, r, onsetMs, sequence, r.grace_deadline_ptb);
        if isfinite(j)
            if r.online_response_sequence ~= io.messages(j).sequence
                r.online_response_sequence = io.messages(j).sequence;
                r.online_button = io.messages(j).sensor;
                r.online_button_ms = io.messages(j).tpad_ms;
                r.online_correct = double(r.online_button == r.expected_button);
                r.online_received_ptb = io.messages(j).rx_complete_ptb;
                r.online_processed_ptb = GetSecs;
                io = eye_work(eye, io, 'message', sprintf(['RESPONSE trial=%d button=%d ' ...
                    'tpad_ms=%.0f sequence=%d correct=%d stage=ONLINE'], trial, ...
                    r.online_button, r.online_button_ms, r.online_response_sequence, r.online_correct));
            end
            r.online_anchor_available = verified;
        else
            r.online_response_sequence = NaN;
            r.online_button = NaN; r.online_button_ms = NaN; r.online_correct = NaN;
            r.online_received_ptb = NaN; r.online_processed_ptb = NaN;
            r.online_anchor_available = false;
        end
        lastCount = analyzedCount;
        if numel(io.messages) > lastCount, continue; end
    end
    estate = eye.state(); if ~isempty(estate.failure), return; end
    if (advance && isfinite(r.online_response_sequence)) || GetSecs >= deadline, return; end
end
end

function draw_frame(window, patch, center, phase, digit)
Screen('FillRect', window, patch.black);
if strcmp(phase, 'fixation')
    Screen('DrawLines', window, [-12 12 0 0; 0 0 -12 12], 3, patch.white, center);
elseif strcmp(phase, 'stimulus')
    Screen('FillOval', window, patch.white, [center - 60 center + 60]);
    DrawFormattedText(window, sprintf('%d', digit), 'center', 'center', patch.black);
end
color = patch.black; if strcmp(phase, 'stimulus'), color = patch.white; end
Screen('FillRect', window, color, patch.rect);
end

function f = flip_record(window, target, trial, phase, edge, index, ifi)
when = 0; if isfinite(target), when = target - ifi / 2; end
[vbl, onset, ended, missed] = Screen('Flip', window, when);
f = struct('index', index, 'trial', trial, 'phase', phase, 'expected_edge', edge, ...
    'scheduled_ptb', target, 'vbl_ptb', vbl, 'onset_ptb', onset, 'flip_end_ptb', ended, 'missed_s', missed);
end

function io = eye_work(eye, io, operation, text)
% Measure serial-poll interruption across each synchronous EyeLink call.
io = tpad_io('poll', io); before = GetSecs;
if isempty(io.failure) && ~io.aborted
    try
        if strcmp(operation, 'check')
            eye.check();
        elseif strcmp(operation, 'start')
            eye.start();
        else
            eye.message(text);
        end
    catch problem
        eye.fail(problem);
    end
end
io = tpad_io('poll', io); eye.gap(operation, before, GetSecs);
end

function io = trial_snapshot(eye, io, records, flips, targets, trial, deadline)
% Analyze a copy; the post-acquisition M2 table remains authoritative.
[copy, matches] = m1_match_optical(io.messages, flips, 10, false, 0.25, 50);
[~, rows] = m2_trials(copy, records, matches, targets); r = rows(trial);
correct = NaN;
if strcmp(r.outcome, 'CORRECT')
    correct = 1;
elseif strcmp(r.outcome, 'INCORRECT')
    correct = 0;
end
names = {'trial_number','displayed_digit','expected_button','actual_button_snapshot', ...
    'correct_snapshot','hardware_rt_ms_snapshot','optical_on_ms_snapshot','button_ms_snapshot'};
values = [trial targets(trial) targets(trial) r.actual_button correct r.rt_ms r.optical_on_ms r.button_press_ms];
for k = 1:numel(names)
    value = 'NA'; if isfinite(values(k)), value = sprintf('%.0f', values(k)); end
    io = eye_work(eye, io, 'message', sprintf('!V TRIAL_VAR %s %s', names{k}, value));
    io = m1_wait(io, min(deadline, GetSecs + 0.001));
    if ~check_eye(io, eye, deadline), return; end
end
for text = {['!V TRIAL_VAR outcome_snapshot ' r.outcome], ...
        ['!V TRIAL_VAR response_validity_snapshot ' r.response_validity], ...
        '!V TRIAL_VAR analysis_stage ONLINE_SNAPSHOT', 'TRIAL_RESULT 0'}
    io = eye_work(eye, io, 'message', text{1});
    io = m1_wait(io, min(deadline, GetSecs + 0.001));
    if ~check_eye(io, eye, deadline), return; end
end
end

function ok = check_eye(io, eye, deadline)
% Do not throw inside a routine returning acquired io: return it to the caller.
estate = eye.state();
ok = false;
if ~isempty(io.failure) || io.aborted || ~isempty(estate.failure), return; end
if GetSecs >= deadline
    eye.fail(MException('M3:Timing', 'EyeLink messages overran the fixed 500 ms ITI.'));
    return;
end
ok = true;
end
