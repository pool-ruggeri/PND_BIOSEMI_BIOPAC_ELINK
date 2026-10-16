function [messages, matches, summary, pulses] = m1_match_optical(messages, flips, ...
    expectedCycles, complete, maxLatency, durationToleranceMs)
%M1_MATCH_OPTICAL Conservatively associate events with isolated visual edges.
% A host receipt gate identifies a candidate transition, not clock alignment.
% Late/ambiguous reports stay unmatched. No timestamp or edge is invented.
transitions = flips;
if ~isempty(flips), transitions = flips(~cellfun('isempty', {flips.expected_edge})); end
% Presentation context is a safeguard, not a source of filter durations.
transitionContext = zeros(1, numel(messages));
intendedMs = NaN(1, numel(transitions));
for k = 1:numel(transitions)
    if isempty(messages), break; end
    f = transitions(k);
    stop = f.onset_ptb + maxLatency;
    if k < numel(transitions), stop = min(stop, transitions(k + 1).onset_ptb); end
    gate = [messages.rx_first_ptb] >= f.onset_ptb & [messages.rx_first_ptb] < stop;
    gateIndex = -k; if f.expected_edge == 'R', gateIndex = k; end
    transitionContext(gate) = gateIndex;
    if f.expected_edge == 'P' && k < numel(transitions) && ...
            transitions(k + 1).expected_edge == 'R'
        intendedMs(k) = 1000 * (transitions(k + 1).onset_ptb - f.onset_ptb);
    end
end
[messages, pulses] = m1_classify_optical(messages, transitionContext, ...
    intendedMs, durationToleranceMs);
template = struct('flip_index', 0, 'trial', 0, 'edge', '', 'event_sequence', NaN, ...
    'tpad_ms', NaN, 'candidates', 0);
matches = repmat(template, numel(transitions), 1);
for k = 1:numel(transitions)
    f = transitions(k);
    matches(k).flip_index = f.index; matches(k).trial = f.trial;
    matches(k).edge = f.expected_edge;
    candidates = [];
    stop = f.onset_ptb + maxLatency;
    if k < numel(transitions), stop = min(stop, transitions(k + 1).onset_ptb); end
    for j = 1:numel(messages)
        m = messages(j);
        if strcmp(m.kind, 'event') && strcmp(m.channel, 'C') && m.sensor == 1 && ...
                m.rx_first_ptb >= f.onset_ptb && ...
                m.rx_first_ptb < stop
            messages(j).trial = f.trial;
            if m.optical_glitch
                messages(j).label = m.optical_class;
                continue;
            end
            messages(j).label = 'UNMATCHED_OPTICAL';
            if m.edge == f.expected_edge && ...
                    ~m.duplicate && ~m.out_of_order && ~m.state_error
                candidates(end + 1) = j; %#ok<AGROW>
            end
        end
    end
    matches(k).candidates = numel(candidates);
    if numel(candidates) == 1
        j = candidates(1);
        % A candidate must not already have been assigned to another edge.
        if ~any([matches.event_sequence] == messages(j).sequence)
            matches(k).event_sequence = messages(j).sequence;
            matches(k).tpad_ms = messages(j).tpad_ms;
            messages(j).label = ['OPTICAL_' f.expected_edge];
        end
    end
end
summary = struct('expected_on', expectedCycles, 'detected_on', 0, ...
    'raw_detected_on', 0, 'raw_detected_off', 0, 'ignored_glitch_pairs', 0, ...
    'expected_off', expectedCycles, 'detected_off', 0, 'matched_on', 0, ...
    'matched_off', 0, 'missing_events', 2 * expectedCycles, ...
    'duplicate_events', 0, 'unexpected_events', 0, 'unexpected_optical_events', 0, ...
    'out_of_order_events', 0, ...
    'malformed_messages', 0, 'state_errors', 0, 'timing_errors', 0, ...
    'missed_flip_deadlines', 0, 'presented_transitions', numel(transitions), ...
    'recovered_pulses', 0, 'missing_pulses', expectedCycles, ...
    'duration_min_ms', NaN, 'duration_max_ms', NaN, 'pulse_recovery_result', 'FAIL', ...
    'result', 'FAIL');
% Raw totals include setup/startup reports, including runs with no flips.
if ~isempty(messages)
    opto = strcmp({messages.kind}, 'event') & strcmp({messages.channel}, 'C') & ...
        [messages.sensor] == 1;
    summary.raw_detected_on = sum(opto & strcmp({messages.edge}, 'P'));
    summary.raw_detected_off = sum(opto & strcmp({messages.edge}, 'R'));
    summary.ignored_glitch_pairs = sum(opto & [messages.optical_glitch] & ...
        strcmp({messages.edge}, 'P'));
end
if isempty(transitions), return; end
active = messages;
if ~isempty(active), active = active([active.rx_first_ptb] >= transitions(1).onset_ptb); end
if ~isempty(active)
    active = active(~[active.optical_glitch]);
    opto = strcmp({active.kind}, 'event') & strcmp({active.channel}, 'C') & ...
        [active.sensor] == 1;
    summary.detected_on = sum(opto & strcmp({active.edge}, 'P'));
    summary.detected_off = sum(opto & strcmp({active.edge}, 'R'));
    summary.duplicate_events = sum([active.duplicate]);
    summary.out_of_order_events = sum([active.out_of_order]);
    summary.state_errors = sum([active.state_error]);
    summary.malformed_messages = sum(ismember({active.kind}, {'malformed', 'incomplete'}));
    matched = ismember([active.sequence], [matches.event_sequence]);
    summary.unexpected_optical_events = sum(opto & ~matched & ~[active.duplicate]);
    summary.unexpected_events = sum((strcmp({active.kind}, 'event') | ...
        strcmp({active.kind}, 'unexpected')) & ~matched & ~[active.duplicate]);
    % Setup mode replies are outside this interval; any later reply is unexpected.
    summary.unexpected_events = summary.unexpected_events + ...
        sum(ismember({active.kind}, {'mode', 'number'}));
end
summary.matched_on = sum(strcmp({matches.edge}, 'P') & isfinite([matches.tpad_ms]));
summary.matched_off = sum(strcmp({matches.edge}, 'R') & isfinite([matches.tpad_ms]));
summary.missing_events = 2 * expectedCycles - summary.matched_on - summary.matched_off;
durations = [];
for k = 1:numel(pulses)
    p = pulses(k); on = p.transition_index;
    if strcmp(p.classification, 'VALID_INTENDED_PULSE') && ...
            matches(on).event_sequence == p.on_sequence && ...
            matches(on + 1).event_sequence == p.off_sequence
        durations(end + 1) = p.duration_ms; %#ok<AGROW>
    end
end
summary.recovered_pulses = numel(durations);
summary.missing_pulses = expectedCycles - numel(durations);
if ~isempty(durations)
    summary.duration_min_ms = min(durations); summary.duration_max_ms = max(durations);
end
for k = 2:numel(matches)
    if all(isfinite([matches(k - 1:k).tpad_ms]))
        hardwareDuration = matches(k).tpad_ms - matches(k - 1).tpad_ms;
        displayDuration = 1000 * (transitions(k).onset_ptb - transitions(k - 1).onset_ptb);
        summary.timing_errors = summary.timing_errors + ...
            (abs(hardwareDuration - displayDuration) > durationToleranceMs);
    end
end
summary.missed_flip_deadlines = sum([transitions.missed_s] > 0 & ...
    isfinite([transitions.scheduled_ptb]));
problems = [summary.missing_events summary.missing_pulses summary.duplicate_events summary.unexpected_events ...
    summary.out_of_order_events summary.malformed_messages summary.state_errors ...
    summary.timing_errors];
if complete && numel(transitions) == 2 * expectedCycles && ...
        summary.detected_on == expectedCycles && summary.detected_off == expectedCycles && ...
        all(problems == 0)
    summary.pulse_recovery_result = 'PASS';
    if summary.missed_flip_deadlines == 0, summary.result = 'PASS'; end
end
end
