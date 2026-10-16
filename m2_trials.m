function [messages, trials] = m2_trials(messages, records, matches, targets)
%M2_TRIALS Four-choice first responses, hardware RTs and auditable partial data.
template = struct('trial', 0, 'displayed_digit', NaN, 'expected_button', NaN, ...
    'actual_button', NaN, 'outcome', 'NOT_PRESENTED', 'response_validity', 'not_presented', ...
    'optical_on_ms', NaN, 'optical_on_sequence', NaN, 'optical_off_ms', NaN, 'button_press_ms', NaN, ...
    'button_release_ms', NaN, 'button_press_sequence', NaN, 'rt_ms', NaN, ...
    'stimulus_flip_ptb', NaN, 'stimulus_offset_ptb', NaN, ...
    'response_deadline_ptb', NaN, 'response_close_ptb', NaN, 'iti_start_ptb', NaN, ...
    'online_response_sequence', NaN, 'online_button', NaN, 'online_button_ms', NaN, 'online_correct', NaN, ...
    'online_received_ptb', NaN, 'online_processed_ptb', NaN, ...
    'premature_response', false, 'late_response', false, 'late_serial_report', false, ...
    'extra_presses', 0, 'optical_artifact_pairs', 0, 'missing_optical_on', true, ...
    'missing_optical_off', true, 'ambiguous_optical_on', false, 'ambiguous_optical_off', false, ...
    'missing_release', false, 'online_response_rejected', false, 'serial_grace_used', false);
trials = repmat(template, numel(records), 1);
releases = NaN(1, numel(messages)); pending = zeros(1, 4);
for j = 1:numel(messages)
    m = messages(j);
    if ~is_button(m) || m.duplicate || m.out_of_order || m.state_error, continue; end
    if m.edge == 'P'
        pending(m.sensor) = j;
    elseif pending(m.sensor) > 0
        releases(pending(m.sensor)) = j; pending(m.sensor) = 0;
    end
end
for t = 1:numel(records)
    r = records(t); trials(t).trial = t;
    trials(t).displayed_digit = targets(t); trials(t).expected_button = targets(t);
    trials(t).stimulus_flip_ptb = r.onset_ptb; trials(t).stimulus_offset_ptb = r.offset_ptb;
    trials(t).response_deadline_ptb = r.response_deadline_ptb;
    trials(t).response_close_ptb = r.response_close_ptb; trials(t).iti_start_ptb = r.iti_start_ptb;
    trials(t).online_response_sequence = r.online_response_sequence;
    trials(t).online_button = r.online_button; trials(t).online_button_ms = r.online_button_ms;
    trials(t).online_correct = r.online_correct;
    trials(t).online_received_ptb = r.online_received_ptb;
    trials(t).online_processed_ptb = r.online_processed_ptb;
    if ~isfinite(r.onset_ptb), continue; end
    on = []; off = [];
    if ~isempty(matches)
        on = matches([matches.trial] == t & strcmp({matches.edge}, 'P'));
        off = matches([matches.trial] == t & strcmp({matches.edge}, 'R'));
    end
    onsetSequence = NaN;
    if numel(on) == 1
        trials(t).optical_on_ms = on.tpad_ms; onsetSequence = on.event_sequence;
        trials(t).optical_on_sequence = onsetSequence;
        trials(t).missing_optical_on = ~isfinite(on.tpad_ms);
        trials(t).ambiguous_optical_on = on.candidates > 1;
    end
    if numel(off) == 1
        trials(t).optical_off_ms = off.tpad_ms;
        trials(t).missing_optical_off = ~isfinite(off.tpad_ms);
        trials(t).ambiguous_optical_off = off.candidates > 1;
    end
    limit = r.response_close_ptb;
    if ~isfinite(limit), limit = r.grace_deadline_ptb; end
    [j, verified] = m2_response(messages, r, trials(t).optical_on_ms, onsetSequence, limit);
    if isfinite(j)
        m = messages(j);
        trials(t).actual_button = m.sensor; trials(t).button_press_ms = m.tpad_ms;
        trials(t).button_press_sequence = m.sequence;
        trials(t).outcome = 'INCORRECT';
        if m.sensor == targets(t), trials(t).outcome = 'CORRECT'; end
        trials(t).response_validity = 'unverified_missing_optical_onset';
        if verified
            trials(t).rt_ms = m.tpad_ms - trials(t).optical_on_ms;
            trials(t).response_validity = 'valid';
        end
        trials(t).serial_grace_used = m.rx_complete_ptb > r.response_deadline_ptb;
        messages(j).label = 'RESPONSE_BUTTON_PRESS'; messages(j).trial = t;
        if ~verified, messages(j).label = 'UNVERIFIED_BUTTON_PRESS'; end
        if isfinite(releases(j))
            trials(t).button_release_ms = messages(releases(j)).tpad_ms;
        else
            trials(t).missing_release = true;
        end
        % Preserve all later eligible presses, without replacing the first.
        extraRecord = r; extraRecord.start_sequence = m.sequence;
        while true
            extra = m2_response(messages, extraRecord, trials(t).optical_on_ms, onsetSequence, limit);
            if ~isfinite(extra), break; end
            messages(extra).label = 'EXTRA_BUTTON_PRESS'; messages(extra).trial = t;
            trials(t).extra_presses = trials(t).extra_presses + 1;
            extraRecord.start_sequence = messages(extra).sequence;
        end
    else
        trials(t).outcome = 'INCOMPLETE'; trials(t).response_validity = 'incomplete_window';
        if r.window_completed
            trials(t).outcome = 'TIMEOUT'; trials(t).response_validity = 'missing_response';
        end
    end
    trials(t).online_response_rejected = isfinite(r.online_response_sequence) && ...
        (~isfinite(j) || r.online_response_sequence ~= trials(t).button_press_sequence);
    if ~isempty(messages) && isfield(messages, 'optical_glitch')
        trials(t).optical_artifact_pairs = sum([messages.trial] == t & ...
            [messages.optical_glitch] & strcmp({messages.edge}, 'P'));
    end
end
% Remaining presses retain fixation/late/after-response context. No HID input.
for j = 1:numel(messages)
    m = messages(j);
    if ~is_button(m) || m.edge ~= 'P' || ~isempty(m.label), continue; end
    t = find([records.fixation_ptb] <= m.rx_first_ptb, 1, 'last');
    if isempty(t), messages(j).label = 'PRE_TRIAL_BUTTON_PRESS'; continue; end
    r = records(t); messages(j).trial = t;
    if m.duplicate || m.out_of_order || m.state_error
        messages(j).label = 'INVALID_BUTTON_PRESS';
    elseif ~isfinite(r.onset_ptb) || m.rx_first_ptb < r.onset_ptb || ...
            (isfinite(trials(t).optical_on_ms) && (m.tpad_ms < trials(t).optical_on_ms || ...
            (m.tpad_ms == trials(t).optical_on_ms && m.sequence < trials(t).optical_on_sequence)))
        messages(j).label = 'PREMATURE_BUTTON_PRESS'; trials(t).premature_response = true;
    elseif isfinite(trials(t).optical_on_ms) && m.tpad_ms - trials(t).optical_on_ms > 1500
        messages(j).label = 'LATE_BUTTON_PRESS'; trials(t).late_response = true;
    elseif m.rx_complete_ptb > r.grace_deadline_ptb
        messages(j).label = 'LATE_SERIAL_REPORT'; trials(t).late_serial_report = true;
    elseif ~isfinite(trials(t).optical_on_ms) && m.rx_first_ptb > r.response_deadline_ptb
        messages(j).label = 'UNVERIFIED_LATE_BUTTON_PRESS'; trials(t).late_response = true;
    else
        messages(j).label = 'POST_RESPONSE_BUTTON_PRESS';
    end
end
% Per-button release pairing spans ITI/fixation/trial boundaries and keeps SYNC.
for j = 1:numel(messages)
    if ~is_button(messages(j)) || messages(j).edge ~= 'P' || ~isfinite(releases(j)), continue; end
    release = releases(j);
    if isempty(messages(release).label)
        messages(release).trial = messages(j).trial;
        messages(release).label = ['RELEASE_AFTER_' messages(j).label];
    end
end
end

function yes = is_button(m)
yes = strcmp(m.kind, 'event') && strcmp(m.channel, 'A') && ismember(m.sensor, 1:4);
end
