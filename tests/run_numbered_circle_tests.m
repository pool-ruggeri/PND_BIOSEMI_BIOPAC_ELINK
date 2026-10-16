function run_numbered_circle_tests
%RUN_NUMBERED_CIRCLE_TESTS Hardware eligibility, four channels and partial data.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
r = struct('fixation_ptb', 9, 'onset_ptb', 10, 'offset_ptb', 10.5, ...
    'response_deadline_ptb', 11.5, 'grace_deadline_ptb', 11.6, ...
    'response_close_ptb', 11.6, 'iti_start_ptb', 11.6, 'start_sequence', 0, ...
    'online_response_sequence', NaN, 'online_button', NaN, 'online_button_ms', NaN, ...
    'online_correct', NaN, 'online_received_ptb', NaN, ...
    'online_processed_ptb', NaN, 'online_anchor_available', false, 'window_completed', true);
flips = struct('index', {1, 2}, 'trial', {1, 1}, 'expected_edge', {'P', 'R'}, ...
    'onset_ptb', {10, 10.5}, 'scheduled_ptb', {10, 10.5}, 'missed_s', {-0.001, -0.001});
for button = 1:4
    messages = decode({'C P 1 900000', sprintf('A P %d 900200', button), ...
        'C R 1 900500', sprintf('A R %d 900600', button)}, [10.01 10.21 10.51 10.61]);
    [messages, matches] = m1_match_optical(messages, flips, 1, true, 0.25, 50);
    [messages, t] = m2_trials(messages, r, matches, button);
    assert(strcmp(t.outcome, 'CORRECT') && t.actual_button == button && t.rt_ms == 200);
    assert(t.button_release_ms == 900600 && ~t.missing_release);
    assert(sum(strcmp({messages.label}, 'RESPONSE_BUTTON_PRESS')) == 1);
end
% Wrong buttons have a real RT and are accepted without waiting for correction.
messages = decode({'C P 1 900000', 'C R 1 900500', ...
    'A P 3 900900', 'A R 3 900910'}, [10.01 10.51 10.91 10.92]);
[messages, matches] = m1_match_optical(messages, flips, 1, true, 0.25, 50);
[~, t] = m2_trials(messages, r, matches, 2);
assert(strcmp(t.outcome, 'INCORRECT') && t.rt_ms == 900 && t.actual_button == 3);

% Hardware RT, not receipt latency, determines eligibility during bounded grace.
for test = [1490 1500 1501 1490; 11.55 11.55 11.55 11.61; 1 1 0 0]
    messages = decode({'C P 1 900000', 'C R 1 900500', ...
        sprintf('A P 1 %d', 900000 + test(1))}, [10.01 10.51 test(2)]);
    [messages, matches] = m1_match_optical(messages, flips, 1, true, 0.25, 50);
    [~, t] = m2_trials(messages, r, matches, 1);
    assert(strcmp(t.outcome, 'CORRECT') == logical(test(3)));
    if test(3)
        assert(t.rt_ms == test(1) && t.serial_grace_used);
    else
        assert(strcmp(t.outcome, 'TIMEOUT') && isnan(t.rt_ms));
    end
end

% Partial optical pairs never block online serial action. Missing/ambiguous
% onset permits receipt-based control but leaves hardware RT unavailable.
messages = decode({'A P 4 900200'}, 10.21);
[j, verified] = m2_response(messages, r, NaN, NaN, r.grace_deadline_ptb);
assert(j == 1 && ~verified);
[~, t] = m2_trials(messages, r, [], 4);
assert(strcmp(t.outcome, 'CORRECT') && isnan(t.rt_ms) && t.missing_optical_on);
ambiguous = matches; ambiguous(1).tpad_ms = NaN; ambiguous(1).event_sequence = NaN;
ambiguous(1).candidates = 2;
[~, t] = m2_trials(messages, r, ambiguous, 4);
assert(t.ambiguous_optical_on && isnan(t.rt_ms));
messages = decode({'A P 4 901490'}, 11.55);
assert(isnan(m2_response(messages, r, NaN, NaN, r.grace_deadline_ptb)));

% A same-ms press before the retained ON is premature by serial order.
messages = decode({'A P 1 900000', 'A R 1 900000', 'C P 1 900000', ...
    'A P 2 900200', 'A P 3 900300', 'C R 1 900500', ...
    'A R 2 900600', 'A R 3 900700'}, ...
    [10.001 10.002 10.003 10.21 10.31 10.51 10.61 10.71]);
[messages, matches] = m1_match_optical(messages, flips, 1, true, 0.25, 50);
[messages, t] = m2_trials(messages, r, matches, 2);
assert(t.premature_response && t.actual_button == 2 && t.extra_presses == 1 && t.rt_ms == 200);
assert(t.button_release_ms == 900600);
assert(strcmp(messages(5).label, 'EXTRA_BUTTON_PRESS') && messages(8).trial == 1);

% Without a completed response window an abort is INCOMPLETE, not a timeout.
partial = r; partial.window_completed = false; partial.response_close_ptb = 10.3;
[~, t] = m2_trials([], partial, [], 1);
assert(strcmp(t.outcome, 'INCOMPLETE') && isnan(t.button_press_ms));
partial.onset_ptb = NaN;
[~, t] = m2_trials([], partial, [], 1);
assert(strcmp(t.outcome, 'NOT_PRESENTED'));
fprintf('PASS: 6 M2 analysis regression groups (B1..B4, accuracy, deadline/grace, missing/ambiguous onset, ordering, partial runs).\n');
end

function messages = decode(lines, receipts)
state = []; messages = [];
for k = 1:numel(lines)
    [state, m] = tpad_parse(state, uint8(sprintf('%s\r\n', lines{k})), receipts(k));
    messages = [messages; m]; %#ok<AGROW>
end
end
