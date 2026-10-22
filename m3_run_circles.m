function m3_run_circles(root, port, blockCount)
%M3_RUN_CIRCLES Shared validated trial controller for the M3 and M5 launchers.
assert(ismember(blockCount,[1 4]), 'M3:Order', 'Expected one or four blocks.');
multi = blockCount > 1; name = 'numbered_circle_eyelink';
if multi, name = [name '_4blocks']; end
run = m1_log('new', root, name);
eye = m3_eyelink(run.folder, root, blockCount);
eyeCleanup = onCleanup(eye.release);
run.targets = repmat([1 2 3 4 1 2 3 4 1 2], 1, blockCount);
run.serial_grace_s = 0.100; % Receive delayed bytes; never extend hardware RT >1500 ms.
io = []; window = []; flips = []; matches = []; white = false; currentTrial = 0;
record = struct('fixation_ptb', NaN, 'onset_ptb', NaN, 'offset_ptb', NaN, ...
    'response_deadline_ptb', NaN, 'grace_deadline_ptb', NaN, ...
    'response_close_ptb', NaN, 'iti_start_ptb', NaN, 'start_sequence', 0, ...
    'expected_button', NaN, 'online_response_sequence', NaN, ...
    'online_button', NaN, 'online_button_ms', NaN, 'online_correct', NaN, 'online_received_ptb', NaN, ...
    'online_processed_ptb', NaN, 'online_anchor_available', false, ...
    'window_completed', false);
records = repmat(record, numel(run.targets), 1);
currentBlock = 0;
syncRecord = struct('press_sequence', NaN, 'press_tpad_ms', NaN, ...
    'release_sequence', NaN, 'release_tpad_ms', NaN);
if multi
    run.sync = repmat(syncRecord, 4, 1);
    run.blocks = repmat(struct('block_number',0,'first_trial',0,'last_trial',0, ...
        'status','NOT_PRESENTED','calibration_started_ptb',NaN, ...
        'acquisition_start_ptb',NaN,'acquisition_end_ptb',NaN, ...
        'start_sequence',0,'end_sequence',0,'trials_completed',false,'error',''),4,1);
    for b=1:4
        run.sync(b).block_number=b; run.sync(b).first_global_trial=(b-1)*10+1;
        run.sync(b).eyelink_marker='';
        run.blocks(b).block_number=b; run.blocks(b).first_trial=(b-1)*10+1;
        run.blocks(b).last_trial=b*10;
    end
end
displayCleanup = [];
fprintf(2, ['WARNING: Visual synchronization tests are disabled (SkipSyncTests=1).\n' ...
    'Screen(''Flip'') timestamps are not yet scientifically qualified.\n']);
try
    if multi, openglCleanup=m5_calibration_mask('initialize', [], []); end %#ok<NASGU>
    eye.initialize();
    previousSync = Screen('Preference', 'SkipSyncTests');
    syncCleanup = onCleanup(@() Screen('Preference', 'SkipSyncTests', previousSync));
    Screen('Preference', 'SkipSyncTests', 1);
    screen = max(Screen('Screens'));
    displayCleanup = onCleanup(@() m1_cleanup([]));
    [window, rect, ifi] = m1_display(screen); patch = m1_patch(window, screen);
    run.patch = patch; run.ifi_s = ifi; center = rect(3:4) / 2;
    Screen('FillRect', window, patch.black); Screen('Flip', window);
    for b = 1:blockCount
        currentBlock = b; firstTrial = (b-1)*10+1;
        if multi
            run.blocks(b).status='CALIBRATING'; run.blocks(b).calibration_started_ptb=GetSecs;
            m5_setup_callback('poller', @calibration_poll);
        end
        try
            eye.calibrate(window, patch, b);
        catch problem
            if multi, m5_setup_callback('clear'); end
            rethrow(problem);
        end
        if multi, m5_setup_callback('clear'); end
        if isempty(io)
            io = tpad_io('open', [], port, run.folder);
            serialCleanup = onCleanup(io.release);
        end
        check_running(io);
        io = m1_wait(io, GetSecs + 0.5); check_running(io);
        if multi
            run.blocks(b).status='SYNCHRONIZING'; run.blocks(b).acquisition_start_ptb=GetSecs;
            if ~isempty(io.messages), run.blocks(b).start_sequence=io.messages(end).sequence; end
        end
        io = eye_work(eye, io, 'message', sprintf('TRIALID %d',firstTrial)); check_running(io);
        io = eye_work(eye, io, 'start', ''); check_running(io);
        io = m1_wait(io, GetSecs + 0.1); check_running(io);
        io = eye_work(eye, io, 'check', ''); check_running(io);
        estate = eye.state();
        if b==1
            io = eye_work(eye, io, 'message', ['SESSION_START run_id=' estate.run_id]); check_running(io);
        end
        if multi
            io = eye_work(eye, io, 'message', sprintf('BLOCK_START block=%d',b)); check_running(io);
        end
        lastHealth = GetSecs;
        Screen('FillRect', window, patch.black);
        instruction = 'Press Button 1 to synchronize the recording systems.';
        if multi, instruction = sprintf('Block %d/4 - Press and release Button 1 to synchronize.',b); end
        DrawFormattedText(window, instruction, ...
            'center', 'center', patch.white);
        Screen('FillRect', window, patch.black, patch.rect);
        f = flip_record(window, NaN, 0, 'sync_screen', '', numel(flips)+1, ifi); flips = [flips; f]; %#ok<AGROW>
        cursor = numel(io.messages); press = NaN; syncMarked = false;
        if ~multi, run.sync = syncRecord; end
        while ~isfinite(run.sync(b).release_sequence)
            io = m1_wait(io, GetSecs + 0.001); check_running(io);
            for j = cursor + 1:numel(io.messages)
                m = io.messages(j);
                if ~strcmp(m.kind, 'event') || ~strcmp(m.channel, 'A') || m.sensor ~= 1 || ...
                        m.duplicate || m.out_of_order || m.state_error, continue; end
                if ~isfinite(press) && m.edge == 'P' && m.rx_first_ptb >= f.onset_ptb
                    press = j; io.messages(j).label = 'SYNC_BUTTON_PRESS';
                    run.sync(b).press_sequence = m.sequence; run.sync(b).press_tpad_ms = m.tpad_ms;
                elseif isfinite(press) && m.edge == 'R' && m.tpad_ms >= run.sync(b).press_tpad_ms
                    io.messages(j).label = 'SYNC_BUTTON_RELEASE';
                    run.sync(b).release_sequence = m.sequence; run.sync(b).release_tpad_ms = m.tpad_ms;
                end
            end
            cursor = numel(io.messages);
            if isfinite(run.sync(b).press_tpad_ms) && ~syncMarked && (~multi || isfinite(run.sync(b).release_sequence))
                marker = sprintf('TPAD_SYNC tpad_ms=%.0f sequence=%d', ...
                    run.sync(b).press_tpad_ms, run.sync(b).press_sequence);
                if multi
                    marker = sprintf(['TPAD_SYNC block=%d press_tpad_ms=%.0f press_sequence=%d ' ...
                        'release_tpad_ms=%.0f release_sequence=%d'],b,run.sync(b).press_tpad_ms, ...
                        run.sync(b).press_sequence,run.sync(b).release_tpad_ms,run.sync(b).release_sequence);
                    run.sync(b).eyelink_marker=marker;
                end
                io = eye_work(eye, io, 'message', marker);
                syncMarked = true; check_running(io);
            end
            if GetSecs - lastHealth >= 0.1
                io = eye_work(eye, io, 'check', ''); check_running(io); lastHealth = GetSecs;
            end
        end
        fprintf('SYNC_BUTTON_PRESS: %.0f tPAD ms. Respond with the button matching each digit.\n', ...
            run.sync(b).press_tpad_ms);
        Screen('TextSize', window, 48);
        fixationFrames = max(1, round(1.0 / ifi));
        stimulusFrames = max(1, round(0.5 / ifi));
        if multi, run.blocks(b).status='RUNNING'; end
        for t = firstTrial:firstTrial+9
            if t > firstTrial
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
            [io, records(t)] = listen(io, records(t), flips, t, target - ifi, false, eye, numel(run.targets)); check_running(io);
            f = flip_record(window, target, t, 'stimulus_off', 'R', numel(flips) + 1, ifi);
            white = false; flips = [flips; f]; records(t).offset_ptb = f.onset_ptb; %#ok<AGROW>
            io = eye_work(eye, io, 'message', sprintf('STIMULUS_OFFSET trial=%d flip_ptb=%.9f', t, f.onset_ptb));
            check_running(io);
            [io, records(t)] = listen(io, records(t), flips, t, records(t).grace_deadline_ptb, true, eye, numel(run.targets)); check_running(io);
            records(t).response_close_ptb = GetSecs;
            records(t).window_completed = GetSecs >= records(t).response_deadline_ptb;
            records(t).iti_start_ptb = GetSecs;
            itiEnd = records(t).iti_start_ptb + 0.5;
            io = eye_work(eye, io, 'check', ''); check_running(io);
            io = trial_snapshot(eye, io, records, flips, run.targets, t, itiEnd); check_running(io);
            assert(GetSecs < itiEnd, 'M3:Timing', 'EyeLink work overran the fixed 500 ms ITI.');
            io = m1_wait(io, itiEnd); check_running(io);
        end
        if multi
            run.blocks(b).trials_completed=true;
            io = m1_wait(io, GetSecs+0.1); check_running(io); % Polled SDK event tail outside trials.
            io = eye_work(eye, io, 'stop', ''); check_running(io);
            io = eye_work(eye, io, 'message', sprintf('BLOCK_END block=%d status=COMPLETE',b)); check_running(io);
            run.blocks(b).acquisition_end_ptb=GetSecs;
            if ~isempty(io.messages), run.blocks(b).end_sequence=io.messages(end).sequence; end
            run.blocks(b).status='COMPLETE';
            savedRun=m5_analyze(run,io,records,flips,eye.state());
            savedIo=io; savedIo.messages=savedRun.messages;
            m1_log('save',savedRun,savedIo); save_block_tables(savedRun);
        end
    end
    run.status = 'complete';
catch problem
    run.error = getReport(problem, 'basic', 'hyperlinks', 'off'); run.status = 'error';
    if (~isempty(io) && io.aborted) || strcmp(problem.identifier, 'M3:Abort'), run.status = 'aborted'; end
    if startsWith(problem.identifier, 'M3:'), eye.fail(problem); end
    if multi && currentBlock>0 && ~strcmp(run.blocks(currentBlock).status,'COMPLETE')
        run.blocks(currentBlock).status=upper(run.status); run.blocks(currentBlock).error=run.error;
    end
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
    if multi
        if currentBlock>0 && isfinite(run.blocks(currentBlock).acquisition_start_ptb) && ...
                ~strcmp(run.blocks(currentBlock).status,'COMPLETE')
            run.blocks(currentBlock).acquisition_end_ptb=GetSecs;
            if ~isempty(io.messages), run.blocks(currentBlock).end_sequence=io.messages(end).sequence; end
        end
        run=m5_analyze(run,io,records,flips,eye.state());
        io.messages=run.messages; matches=run.matches;
    else
        run.raw_messages = io.messages;
        [io.messages, matches, optical, run.optical_pulses] = m1_match_optical( ...
            io.messages, flips, 10, strcmp(run.status, 'complete'), 0.25, 50);
        run.optical_summary = struct('raw_on', optical.raw_detected_on, 'raw_off', optical.raw_detected_off, ...
            'matched_on', optical.matched_on, 'matched_off', optical.matched_off, ...
            'artifact_pairs', optical.ignored_glitch_pairs, 'missing_events', optical.missing_events);
        [io.messages, run.trials] = m2_trials(io.messages, records, matches, run.targets);
    end
    io = tpad_io('close', io);
elseif multi
    run=m5_analyze(run,io,records,flips,eye.state()); matches=run.matches;
else
    [~, run.trials] = m2_trials([], records, matches, run.targets);
end
if ~multi
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
else
    sync=run.summary.sync_recorded;
end
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
if multi, run.calibrations=run.eyelink.calibrations; end
run = m1_log('save', run, io);
if multi
    save_block_tables(run);
end
if ~isempty(run.sync)
    writetable(struct2table(run.sync, 'AsArray', true), fullfile(run.folder, 'sync.csv'));
end
s = run.summary; syncText = 'NO'; if sync, syncText = 'YES'; end
if multi
    fprintf('\nFOUR-BLOCK EYELINK TASK: %s | Trials %d/40 | SYNC pairs %d/4\n', ...
        upper(run.status),s.presented_trials,s.sync_count);
    fprintf('Correct %d | Incorrect %d | Timeouts %d | Optical pulses %d/40 | Artifacts %d | Mean RT %.1f ms\n', ...
        s.correct,s.incorrect,s.timeouts,s.valid_optical_pulses,s.optical_artifact_pairs,s.mean_all_response_rt_ms);
    for b=1:4
        row=run.block_summaries(b);
        fprintf('Block %d: %s | Trials %d/10 | Correct %d | Incorrect %d | Timeouts %d | Mean RT %.1f ms\n', ...
            b,row.status,row.presented_trials,row.correct,row.incorrect,row.timeouts,row.mean_all_response_rt_ms);
    end
else
    fprintf(['\nNUMBERED CIRCLE EYELINK TASK\nTrials presented: %d\nCorrect responses: %d\n' ...
        'Incorrect responses: %d\nTimeouts: %d\nValid optical onsets: %d/10\n' ...
        'Valid optical offsets: %d/10\nOptical artifact pairs: %d\nSYNC recorded: %s\n' ...
        'Mean correct RT: %.1f ms\nMean all-response RT: %.1f ms\nRun status: %s\nSaved: %s\n'], ...
        s.presented_trials, s.correct, s.incorrect, s.timeouts, s.valid_optical_onsets, ...
        s.valid_optical_offsets, s.optical_artifact_pairs, syncText, ...
        s.mean_correct_rt_ms, s.mean_all_response_rt_ms, upper(run.status), run.folder);
end
fprintf('Host EDF: %s | Transfer verified: %d | Recovery: %s\n', ...
    run.eyelink.host_edf, run.eyelink.transfer_verified, fullfile(run.folder, 'eyelink_recovery.mat'));
if ~isempty(run.eyelink.failure) && ~contains(run.error, run.eyelink.failure)
    fprintf(2, 'EyeLink: %s\n', run.eyelink.failure);
end
if ~isempty(run.error), fprintf(2, '%s\n', run.error); end

    function calibration_poll
        if ~isempty(io), io=tpad_io('poll',io); end
    end

    function check_running(io)
        assert(isempty(io.failure), 'M1:Serial', ...
            'tPAD serial failure on %s: %s. Close the BBTK app or other port owner before retrying.', io.port, io.failure);
        assert(~io.aborted, 'M1:Abort', 'ESC pressed; acquired data will be saved.');
        estate = eye.state(); assert(isempty(estate.failure), 'M3:EyeLink', '%s', estate.failure);
    end

end

function [io, r] = listen(io, r, flips, trial, deadline, advance, eye, trialCount)
lastCount = -1;
while true
    io = m1_wait(io, min(deadline, GetSecs + 0.001));
    if ~isempty(io.failure) || io.aborted, return; end % Return acquired state before throwing.
    if numel(io.messages) ~= lastCount
        analyzedCount = numel(io.messages);
        % Analyze a copy; incomplete optical pairs never block serial control.
        [copy, contextFlips] = block_context(io.messages, flips, trialCount, trial, eye);
        [~, matches] = m1_match_optical(copy, contextFlips, trialCount, false, 0.25, 50);
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
        elseif strcmp(operation, 'stop')
            eye.stop();
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
[copy, contextFlips] = block_context(io.messages, flips, numel(targets), trial, eye);
[copy, matches] = m1_match_optical(copy, contextFlips, numel(targets), false, 0.25, 50);
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
if numel(targets)>10
    names=[names, {'block_number','trial_in_block','global_trial'}];
    values=[values, ceil(trial/10), mod(trial-1,10)+1, trial];
end
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

function [copy, contextFlips] = block_context(messages, flips, count, trial, eye)
copy=messages; contextFlips=flips;
if count<=10, return; end
b=ceil(trial/10); state=eye.state();
if ~isempty(messages), copy=messages([messages.rx_first_ptb]>=state.segments(b).started_ptb); end
if ~isempty(flips), contextFlips=flips([flips.trial]>(b-1)*10 & [flips.trial]<=b*10); end
end

function save_block_tables(run)
writetable(struct2table(run.blocks,'AsArray',true),fullfile(run.folder,'blocks.csv'));
writetable(struct2table(run.block_summaries,'AsArray',true),fullfile(run.folder,'block_summaries.csv'));
writetable(struct2table(run.calibrations,'AsArray',true),fullfile(run.folder,'calibrations.csv'));
writetable(struct2table(run.sync,'AsArray',true),fullfile(run.folder,'sync.csv'));
end
