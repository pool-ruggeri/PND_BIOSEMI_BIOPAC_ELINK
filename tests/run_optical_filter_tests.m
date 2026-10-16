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
for test = [20 21 1 1; 5 2 6 500; 1 0 0 0]
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

% A short pulse at an intended ON (not immediately post-OFF) stays ambiguous.
onsetBurst = parse_events({'C P 1 900000', 'C R 1 900500', 'C P 1 901000', ...
    'C R 1 901002', 'C P 1 901002', 'C R 1 901500'}, ...
    [10.01 10.51 11.01 11.02 11.03 11.51]);
[m, ~, s] = m1_match_optical(onsetBurst, flips, 2, true, 0.25, 50);
assert(~any([m.optical_glitch]) && s.missing_events == 1 && strcmp(s.result, 'FAIL'));

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
fprintf('PASS: 7 optical filter regression groups (including trial boundaries and unchanged button RT).\n');
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
