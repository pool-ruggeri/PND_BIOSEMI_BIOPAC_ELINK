function [messages, trials] = m1_trials(messages, records, matches)
%M1_TRIALS Pair button edges across boundaries and derive hardware-only RTs.
% Receipt times give trial context when hardware optical anchors are missing;
% such button candidates are explicitly unverified and never produce an RT.
template = struct('trial', 0, 'fixation_ptb', NaN, 'stimulus_flip_ptb', NaN, ...
    'stimulus_offset_ptb', NaN, 'response_deadline_ptb', NaN, ...
    'optical_on_ms', NaN, 'optical_off_ms', NaN, 'button_press_ms', NaN, ...
    'button_release_ms', NaN, 'button_press_sequence', NaN, ...
    'rt_ms', NaN, 'response_validity', 'not_presented', ...
    'missing_optical_on', true, 'missing_optical_off', true, ...
    'premature_presses', 0, 'extra_presses', 0, 'late_presses', 0, ...
    'missing_release', false, 'event_issues', 0, 'response_window_completed', false);
trials = repmat(template, numel(records), 1);
if isempty(messages)
    releaseFor = [];
else
    releaseFor = NaN(1, numel(messages));
end
pending = 0;
for j = 1:numel(messages)
    m = messages(j);
    if ~is_button(m) || m.duplicate || m.out_of_order || m.state_error, continue; end
    if m.edge == 'P'
        pending = j;
    elseif pending > 0
        releaseFor(pending) = j; %#ok<AGROW>
        pending = 0;
    end
end
% Select responses for all trials before assigning remaining presses to
% fixation/ITI. This retains delayed reports near trial boundaries.
for t = 1:numel(records)
    r = records(t); trials(t).trial = t;
    trials(t).fixation_ptb = r.fixation_ptb;
    trials(t).stimulus_flip_ptb = r.onset_ptb;
    trials(t).stimulus_offset_ptb = r.offset_ptb;
    trials(t).response_deadline_ptb = r.response_deadline_ptb;
    trials(t).response_window_completed = r.window_completed;
    if ~isfinite(r.onset_ptb), continue; end
    on = find([matches.trial] == t & strcmp({matches.edge}, 'P') & ...
        isfinite([matches.tpad_ms]));
    off = find([matches.trial] == t & strcmp({matches.edge}, 'R') & ...
        isfinite([matches.tpad_ms]));
    onSequence = NaN;
    if numel(on) == 1
        trials(t).optical_on_ms = matches(on).tpad_ms;
        trials(t).missing_optical_on = false;
        onSequence = matches(on).event_sequence;
    end
    if numel(off) == 1
        trials(t).optical_off_ms = matches(off).tpad_ms;
        trials(t).missing_optical_off = false;
    end
    candidates = [];
    for j = 1:numel(messages)
        m = messages(j);
        if ~is_button(m) || m.edge ~= 'P' || m.duplicate || ...
                m.out_of_order || m.state_error || ~isempty(m.label), continue; end
        if isfinite(onSequence)
            elapsed = m.tpad_ms - trials(t).optical_on_ms;
            eligible = m.sequence > onSequence && elapsed >= 0 && elapsed <= 1500;
        else
            eligible = m.rx_first_ptb >= r.onset_ptb && ...
                m.rx_first_ptb <= r.response_deadline_ptb;
        end
        if eligible, candidates(end + 1) = j; end %#ok<AGROW>
    end
    if isempty(candidates)
        trials(t).response_validity = 'missing_response';
        if ~r.window_completed, trials(t).response_validity = 'incomplete_window'; end
        if ~isfinite(onSequence)
            trials(t).response_validity = 'missing_onset_and_response';
        end
        continue;
    end
    j = candidates(1);
    trials(t).button_press_ms = messages(j).tpad_ms;
    trials(t).button_press_sequence = messages(j).sequence;
    messages(j).trial = t;
    if isfinite(onSequence)
        trials(t).rt_ms = messages(j).tpad_ms - trials(t).optical_on_ms;
        trials(t).response_validity = 'valid';
        messages(j).label = 'RESPONSE_BUTTON_PRESS';
    else
        trials(t).response_validity = 'unverified_missing_optical_onset';
        messages(j).label = 'UNVERIFIED_BUTTON_PRESS';
    end
    release = releaseFor(j);
    if isfinite(release)
        trials(t).button_release_ms = messages(release).tpad_ms;
        messages(release).label = 'RESPONSE_BUTTON_RELEASE';
        messages(release).trial = t;
    else
        trials(t).missing_release = true;
    end
    trials(t).extra_presses = numel(candidates) - 1;
    for extra = candidates(2:end)
        messages(extra).label = 'EXTRA_BUTTON_PRESS'; messages(extra).trial = t;
    end
end
for j = 1:numel(messages)
    m = messages(j);
    if ~is_button(m) || m.edge ~= 'P' || ~isempty(m.label), continue; end
    % Exclude pre-sync activity even if its hardware time happens to fit.
    t = find([records.fixation_ptb] <= m.rx_first_ptb, 1, 'last');
    if isempty(t), messages(j).label = 'PRE_TRIAL_BUTTON_PRESS'; continue; end
    messages(j).trial = t;
    if m.duplicate || m.out_of_order || m.state_error
        messages(j).label = 'INVALID_BUTTON_PRESS';
    elseif isfinite(trials(t).optical_on_ms) && ...
            (m.tpad_ms < trials(t).optical_on_ms || ...
            (m.tpad_ms == trials(t).optical_on_ms && ...
            m.sequence < optical_sequence(matches, t)))
        messages(j).label = 'PREMATURE_BUTTON_PRESS';
        trials(t).premature_presses = trials(t).premature_presses + 1;
    elseif m.rx_first_ptb < records(t).onset_ptb || ~isfinite(records(t).onset_ptb)
        messages(j).label = 'PREMATURE_BUTTON_PRESS';
        trials(t).premature_presses = trials(t).premature_presses + 1;
    else
        messages(j).label = 'LATE_BUTTON_PRESS';
        trials(t).late_presses = trials(t).late_presses + 1;
    end
    release = releaseFor(j);
    if isfinite(release)
        messages(release).trial = t;
        messages(release).label = ['RELEASE_AFTER_' messages(j).label];
    end
end
% Give releases of extra/premature presses the same trial as their press,
% even when they arrive after a later fixation or after the response window.
for j = 1:numel(messages)
    if is_button(messages(j)) && messages(j).edge == 'P' && ...
            messages(j).trial > 0 && isfinite(releaseFor(j))
        release = releaseFor(j);
        if isempty(messages(release).label)
            messages(release).trial = messages(j).trial;
            messages(release).label = ['RELEASE_AFTER_' messages(j).label];
        end
    end
end
for t = 1:numel(records)
    if ~isfinite(records(t).fixation_ptb), continue; end
    stop = Inf;
    if t < numel(records), stop = records(t + 1).fixation_ptb; end
    if ~isfinite(stop), stop = Inf; end
    for j = 1:numel(messages)
        m = messages(j);
        if m.rx_first_ptb < records(t).fixation_ptb || m.rx_first_ptb >= stop, continue; end
        issue = m.duplicate || m.out_of_order || m.state_error || ...
            ismember(m.kind, {'malformed', 'incomplete', 'unexpected', 'mode', 'number'});
        if strcmp(m.kind, 'event')
            issue = issue || (~is_button(m) && ...
                ~(strcmp(m.channel, 'C') && m.sensor == 1)) || ...
                (strcmp(m.channel, 'C') && m.sensor == 1 && ...
                ~ismember(m.sequence, [matches.event_sequence]));
        end
        trials(t).event_issues = trials(t).event_issues + issue;
    end
end
end

function yes = is_button(m)
yes = strcmp(m.kind, 'event') && strcmp(m.channel, 'A') && m.sensor == 1;
end

function sequence = optical_sequence(matches, trial)
k = find([matches.trial] == trial & strcmp({matches.edge}, 'P') & ...
    isfinite([matches.event_sequence]), 1);
sequence = matches(k).event_sequence;
end
