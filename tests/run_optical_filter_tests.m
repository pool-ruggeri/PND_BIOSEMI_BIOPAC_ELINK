function run_optical_filter_tests
%RUN_OPTICAL_FILTER_TESTS Hardware-time classification and conservative guards.
flips = make_flips([10 10.5 11 11.5]);
normal = parse_events({'C P 1 900000', 'C R 1 900500', ...
    'C P 1 901000', 'C R 1 901500'}, [10.01 10.51 11.01 11.51]);
[m, ~, s] = m1_match_optical(normal, flips, 2, true, 0.25, 50);
assert(strcmp(s.result, 'PASS') && ~any([m.optical_glitch]));
assert(strcmp(m(1).optical_class, 'VALID_OPTICAL_ON'));
assert(strcmp(m(2).optical_class, 'VALID_OPTICAL_OFF'));

lines = {'C P 1 900000', 'C R 1 900500', 'C P 1 900501', ...
    'C R 1 900503', 'C P 1 901000', 'C R 1 901500'};
receipts = [10.01 10.51 10.52 10.53 11.01 11.51];
bounce = parse_events(lines, receipts);
[m, matches, s] = m1_match_optical(bounce, flips, 2, true, 0.25, 50);
assert(strcmp(s.result, 'PASS') && s.raw_detected_on == 3 && s.raw_detected_off == 3);
assert(s.detected_on == 2 && s.detected_off == 2 && s.ignored_glitch_pairs == 1);
assert(isequal(find([m.optical_glitch]), [3 4]));
assert(matches(2).tpad_ms == 900500 && matches(3).tpad_ms == 901000);
classified = m1_classify_optical(bounce, [-1 2 2 2 -3 4]);
assert(isequaln(rmfield(classified, {'optical_class', 'optical_glitch'}), bounce));
assert(isequaln(m1_classify_optical(classified, [-1 2 2 2 -3 4]), classified));

% Threshold boundaries; a longer normal pulse after a brief gap is retained.
for test = [17 21 1 1; 3 2 4 500; 1 0 0 0]
    sample = bounce;
    sample(3).tpad_ms = sample(2).tpad_ms + test(1);
    sample(4).tpad_ms = sample(3).tpad_ms + test(2);
    sample = m1_classify_optical(sample, [-1 2 2 2 -3 4]);
    assert(sum([sample.optical_glitch]) == 2 * test(3));
end
% Real intended transitions 1 ms apart, including a 2 ms intended ON pulse.
closeFlips = make_flips([10 10.5 10.501 10.503]);
close = parse_events(lines(1:4), [10.0001 10.5001 10.5011 10.5031]);
[m, ~, s] = m1_match_optical(close, closeFlips, 2, true, 0.25, 50);
assert(~any([m.optical_glitch]) && strcmp(s.result, 'PASS'));
% Batch-delayed close transitions must not be mistaken for bounce in a later
% OFF gate: the anchor must have its preceding intended ON context too.
close(2).rx_first_ptb = 10.504;
close(3).rx_first_ptb = 10.505; close(4).rx_first_ptb = 10.506;
[m, ~, s] = m1_match_optical(close, closeFlips, 2, true, 0.25, 50);
assert(~any([m.optical_glitch]) && strcmp(s.result, 'FAIL'));

% Startup OFF, incomplete pairs, missing edges and anomaly flags are retained.
startup = parse_events({'C R 1 900500', 'C P 1 900501', 'C R 1 900503'}, [10.51 10.52 10.53]);
assert(~any_glitch(startup, [2 2 2]));
assert(~any_glitch(bounce(1:3), [-1 2 2]));
missing = parse_events(lines([1 3 4]), receipts([1 3 4]));
assert(~any_glitch(missing, [0 2 2]));
for flag = {'duplicate', 'out_of_order', 'state_error'}
    sample = bounce; sample(3).(flag{1}) = true;
    assert(~any_glitch(sample, [-1 2 2 2 -3 4]));
end
[~, ~, s] = m1_match_optical(bounce(1:3), flips, 2, false, 0.25, 50);
assert(strcmp(s.result, 'FAIL') && s.missing_events > 0);
[~, ~, s] = m1_match_optical([], [], 2, false, 0.25, 50);
assert(s.missing_events == 4 && strcmp(s.result, 'FAIL'));
[m, ~, s] = m1_match_optical(startup, [], 2, false, 0.25, 50);
assert(s.raw_detected_on == 1 && s.raw_detected_off == 2 && ~any([m.optical_glitch]));
[~, ~, s] = m1_match_optical([], flips, 2, false, 0.25, 50);
assert(s.missing_events == 4 && strcmp(s.result, 'FAIL'));

% A complete short pulse at onset is chatter when immediately followed by
% the intact intended long pulse; use that last actual ON, never an invented one.
onsetBurst = parse_events({'C P 1 900000', 'C R 1 900500', 'C P 1 901000', ...
    'C R 1 901002', 'C P 1 901002', 'C R 1 901500'}, ...
    [10.01 10.51 11.01 11.02 11.03 11.51]);
[m, recovered, s] = m1_match_optical(onsetBurst, flips, 2, true, 0.25, 50);
assert(sum([m.optical_glitch]) == 2 && s.missing_events == 0 && strcmp(s.result, 'PASS'));
assert(recovered(3).tpad_ms == 901002 && s.recovered_pulses == 2);

% Equal-ms P/R/P and R/P/R are real ordered transitions, not duplicates.
equal = parse_events({'C P 1 900000', 'C R 1 900000', 'C P 1 900000', ...
    'C R 1 900500', 'C P 1 900500', 'C R 1 900500', ...
    'C P 1 901000', 'C R 1 901500'}, ...
    [10.001 10.002 10.003 10.501 10.502 10.503 11.001 11.501]);
assert(~any([equal.duplicate] | [equal.state_error] | [equal.out_of_order]));
[m, recovered, s, pulses] = m1_match_optical(equal, flips, 2, true, 0.25, 50);
assert(strcmp(s.result, 'PASS') && s.ignored_glitch_pairs == 2);
assert(recovered(1).event_sequence == 3 && recovered(2).event_sequence == 4);
assert(isequal([m.tpad_ms], [equal.tpad_ms]) && numel(m) == numel(equal));
assert(sum(strcmp({pulses.classification}, 'SHORT_ARTIFACT_ONSET')) == 1);
assert(sum(strcmp({pulses.classification}, 'SHORT_ARTIFACT_OFFSET')) == 1);
% An actual repeated same-level record stays flagged and retained.
repeated = parse_events({'C P 1 1', 'C P 1 1', 'C R 1 1', 'C P 1 1'}, [1 1 1 1]);
assert(repeated(2).duplicate && ~repeated(4).duplicate && ~repeated(4).state_error);

% Several offset pairs in one bounded burst, including a repeated R identity.
burst = parse_events({'C P 1 900000', 'C R 1 900500', 'C P 1 900501', ...
    'C R 1 900503', 'C P 1 900503', 'C R 1 900503', ...
    'C P 1 901000', 'C R 1 901500'}, ...
    [10.01 10.51 10.52 10.53 10.54 10.55 11.01 11.51]);
[m, ~, s] = m1_match_optical(burst, flips, 2, true, 0.25, 50);
assert(s.ignored_glitch_pairs == 2 && sum([m.optical_glitch]) == 4 && strcmp(s.result, 'PASS'));
% No complete long anchor, no suppression; a distant short pulse is unresolved.
noAnchor = onsetBurst(3:5);
assert(~any_glitch(noAnchor, [-3 -3 -3]));
distant = bounce; distant(3).tpad_ms = 900530; distant(4).tpad_ms = 900532;
assert(~any_glitch(distant, [-1 2 2 2 -3 4]));

% Pulse recovery and the original missed-deadline check are separate results.
missed = flips; missed(1).missed_s = 0.001;
[~, ~, s] = m1_match_optical(normal, missed, 2, true, 0.25, 50);
assert(strcmp(s.pulse_recovery_result, 'PASS') && strcmp(s.result, 'FAIL'));

% Delayed receipt crosses the next fixation; button hardware RT/release stays
% in trial 1. A glitch spanning that boundary creates no extra trial/issue.
records = repmat(struct('fixation_ptb', 9, 'onset_ptb', 10, 'offset_ptb', 10.5, ...
    'response_deadline_ptb', 11.5, 'window_completed', true), 2, 1);
records(2).fixation_ptb = 10.515; records(2).onset_ptb = 11;
records(2).offset_ptb = 11.5; records(2).response_deadline_ptb = 12.5;
task = parse_events([lines(1:3) {'A P 1 900502'} lines(4:end) {'A R 1 901510'}], ...
    [10.01 10.51 10.514 10.516 10.518 11.01 11.51 11.52]);
buttons = task(strcmp({task.channel}, 'A'));
[task, matched] = m1_match_optical(task, flips, 2, true, 0.25, 50);
[task, trials] = m1_trials(task, records, matched);
assert(numel(trials) == 2 && trials(1).rt_ms == 502 && trials(1).button_release_ms == 901510);
assert(all([trials.event_issues] == 0));
after = task(strcmp({task.channel}, 'A'));
assert(isequaln(rmfield(after, {'label', 'trial', 'optical_class', 'optical_glitch'}), ...
    rmfield(buttons, {'label', 'trial'})));
% Nonzero onset chatter must anchor RT to the actual long-pulse ON (+2 ms).
task = parse_events({'A P 1 899000', 'A R 1 899100', ...
    'C P 1 900000', 'C R 1 900002', 'C P 1 900002', 'A P 1 900252', ...
    'C R 1 900502', 'A R 1 900600', 'C P 1 901000', 'C R 1 901500'}, ...
    [8 8.1 10.001 10.002 10.003 10.26 10.51 10.61 11.01 11.51]);
task(1).label = 'SYNC_BUTTON_PRESS'; task(2).label = 'SYNC_BUTTON_RELEASE';
buttonTimes = [task(strcmp({task.channel}, 'A')).tpad_ms];
[task, matched] = m1_match_optical(task, flips, 2, true, 0.25, 50);
[task, trials] = m1_trials(task, records, matched);
assert(trials(1).optical_on_ms == 900002 && trials(1).rt_ms == 250);
assert(isequal([task(strcmp({task.channel}, 'A')).tpad_ms], buttonTimes));
assert(strcmp(task(1).label, 'SYNC_BUTTON_PRESS') && strcmp(task(2).label, 'SYNC_BUTTON_RELEASE'));
fprintf('PASS: 10 optical regression groups (onset/offset/equal-ms chatter, pulse recovery, unchanged button RT).\n');
end

function yes = any_glitch(messages, context)
messages = m1_classify_optical(messages, context);
yes = any([messages.optical_glitch]);
end

function messages = parse_events(lines, receipts)
state = []; messages = [];
for k = 1:numel(lines)
    [state, m] = tpad_parse(state, uint8(sprintf('%s\r\n', lines{k})), receipts(k));
    messages = [messages; m]; %#ok<AGROW>
end
end

function flips = make_flips(times)
flips = [];
for k = 1:numel(times)
    edge = 'R'; if mod(k, 2), edge = 'P'; end
    flips = [flips; struct('index', k, 'trial', ceil(k / 2), 'expected_edge', edge, ...
        'onset_ptb', times(k), 'scheduled_ptb', times(k), 'missed_s', -0.001)]; %#ok<AGROW>
end
end
