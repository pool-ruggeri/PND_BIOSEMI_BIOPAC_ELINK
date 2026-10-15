function run_offline_tests
%RUN_OFFLINE_TESTS Small deterministic tests; no Screen, IOPort, or tPAD use.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
groups = 0;
stream = uint8(sprintf(['MODE 5:\r\nA P 1 123456\r\nA R 1 123600\r\n' ...
    'C P 1 124000\r\nC R 1 124500\r\nA P 10 125000\r\n' ...
    'C P 2 125100\r\nM P 1 125200\r\nT P 1 125300\r\n']));
[~, reference] = tpad_parse([], stream, 10);
assert(numel(reference) == 9 && strcmp(reference(1).kind, 'mode'));
assert(isequal([reference(2:5).tpad_ms], [123456 123600 124000 124500]));
assert(isequal({reference(2:5).channel}, {'A', 'A', 'C', 'C'}));
assert(isequal({reference(2:5).edge}, {'P', 'R', 'P', 'R'}));
assert(all(strcmp({reference(2:end).kind}, 'event')));
groups = groups + 1;
% Every possible two-read split, including inside CRLF and timestamps.
for split = 0:numel(stream)
    [state, first] = tpad_parse([], stream(1:split), 10);
    [state, second] = tpad_parse(state, stream(split + 1:end), 10);
    [~, tail] = tpad_parse(state, [], 10, true);
    assert(isequaln([first; second; tail], reference));
end
state = []; allMessages = [];
for byte = stream
    [state, messages] = tpad_parse(state, byte, 10);
    allMessages = [allMessages; messages]; %#ok<AGROW>
end
assert(isequaln(allMessages, reference));
groups = groups + 1;
[state, messages] = tpad_parse([], uint8(sprintf( ...
    'A P 1 7\rA R 1 8\nC P 1 9\r\nC R 1 10\n')), 3);
assert(numel(messages) == 4 && isempty(state.buffer));
[state, messages] = tpad_parse([], uint8('C P 1 777'), 3);
assert(isempty(messages));
[~, messages] = tpad_parse(state, [], 4, true);
assert(strcmp(messages.kind, 'incomplete') && isnan(messages.tpad_ms));
assert(messages.rx_first_ptb == 3 && messages.rx_complete_ptb == 4);
groups = groups + 1;
bad = [uint8(sprintf('A P 1 nope\nC X 1 23\nA P 1 -1\nA P 1 1.5\n')) ...
    uint8([255 10]) uint8(sprintf('A P 1 9007199254740993\nZ P 1 12\nC P 3 13\n'))];
[~, messages] = tpad_parse([], bad, 1);
assert(sum(strcmp({messages.kind}, 'malformed')) == 6);
assert(sum(strcmp({messages.kind}, 'unexpected')) == 2);
[state, messages] = tpad_parse([], uint8(repmat('x', 1, 4096)), 1);
assert(strcmp(messages.kind, 'malformed'));
[~, messages] = tpad_parse(state, uint8(sprintf('A P 1 22\nC P 1 23\n')), 2);
assert(strcmp(messages(1).kind, 'malformed') && strcmp(messages(2).kind, 'event'));
groups = groups + 1;
[~, messages] = tpad_parse([], uint8(sprintf( ...
    'C P 1 100\nC P 1 100\nC P 1 101\nC R 1 99\n')), 1);
assert(messages(2).duplicate && messages(3).state_error && messages(4).out_of_order);
assert(isequal([messages.tpad_ms], [100 100 101 99]));
groups = groups + 1;

% Optical matching uses separate host and hardware epochs deliberately.
flips = make_flips([10 10.5 11 11.5]);
state = []; messages = [];
for k = 1:4
    [state, m] = tpad_parse(state, uint8(sprintf('C %s 1 %d\r\n', ...
        flips(k).expected_edge, 900000 + (k - 1) * 500)), flips(k).onset_ptb + 0.01);
    messages = [messages; m]; %#ok<AGROW>
end
[~, matches, summary] = m1_match_optical(messages, flips, 2, true, 0.25, 50);
assert(strcmp(summary.result, 'PASS') && summary.missing_events == 0);
assert(matches(1).tpad_ms == 900000);
groups = groups + 1;
% One loss must not shift the remaining cycle assignments.
lost = messages([1 3 4]);
[~, matched, summary] = m1_match_optical(lost, flips, 2, true, 0.25, 50);
assert(strcmp(summary.result, 'FAIL') && summary.missing_events == 1);
assert(isnan(matched(2).tpad_ms) && matched(3).tpad_ms == 901000);
% Correct totals with wrong sequence/timing still fail.
wrong = messages;
wrong(2).edge = 'P'; wrong(3).edge = 'R';
[~, ~, summary] = m1_match_optical(wrong, flips, 2, true, 0.25, 50);
assert(summary.detected_on == 2 && summary.detected_off == 2);
assert(strcmp(summary.result, 'FAIL'));
duplicate = messages(1); duplicate.sequence = 99; duplicate.duplicate = true;
[~, ~, summary] = m1_match_optical([messages; duplicate], flips, 2, true, 0.25, 50);
assert(summary.duplicate_events == 1 && strcmp(summary.result, 'FAIL'));
late = messages; late(1).rx_first_ptb = 10.3;
[~, ~, summary] = m1_match_optical(late, flips, 2, true, 0.25, 50);
assert(summary.missing_events == 1 && strcmp(summary.result, 'FAIL'));
backwards = messages; backwards(3).out_of_order = true;
[~, ~, summary] = m1_match_optical(backwards, flips, 2, true, 0.25, 50);
assert(summary.out_of_order_events == 1 && strcmp(summary.result, 'FAIL'));
groups = groups + 1;

% A response and release received during the following fixation must remain
% with the original trial when hardware timestamps establish eligibility.
records = repmat(struct('fixation_ptb', 9, 'onset_ptb', 10, ...
    'offset_ptb', 10.5, 'response_deadline_ptb', 11.5, 'window_completed', true), 2, 1);
records(2).fixation_ptb = 12; records(2).onset_ptb = 13;
records(2).offset_ptb = 13.5; records(2).response_deadline_ptb = 14.5;
state = []; events = [];
lines = {'A P 1 899000', 'A R 1 899100', 'A P 1 899700', 'A R 1 899800', ...
    'C P 1 900000', 'C R 1 900500', 'A P 1 901000', 'A R 1 901100', ...
    'C P 1 903000', 'A P 1 903250', 'C R 1 903500', 'A R 1 903800'};
receipts = [8 8.1 9.7 9.8 10.01 10.51 12.01 12.02 13.01 13.26 13.51 13.81];
for k = 1:numel(lines)
    [state, m] = tpad_parse(state, uint8(sprintf('%s\r\n', lines{k})), receipts(k));
    events = [events; m]; %#ok<AGROW>
end
events(1).label = 'SYNC_BUTTON_PRESS'; events(2).label = 'SYNC_BUTTON_RELEASE';
taskFlips = make_flips([10 10.5 13 13.5]);
[events, taskMatches] = m1_match_optical(events, taskFlips, 2, true, 0.25, 50);
[events, trials] = m1_trials(events, records, taskMatches);
assert(trials(1).rt_ms == 1000 && trials(2).rt_ms == 250);
assert(trials(1).button_release_ms == 901100 && trials(1).premature_presses == 1);
assert(strcmp(events(1).label, 'SYNC_BUTTON_PRESS') && events(7).trial == 1);
groups = groups + 1;
noOnset = taskMatches; noOnset(3).tpad_ms = NaN; noOnset(3).event_sequence = NaN;
% Use unlabeled input again to exercise the missing-onset branch.
for k = 3:numel(events), events(k).label = ''; end
[~, trials] = m1_trials(events, records, noOnset);
assert(isnan(trials(2).rt_ms) && ...
    strcmp(trials(2).response_validity, 'unverified_missing_optical_onset'));
noResponse = events; noResponse(10).label = 'EXCLUDED_FOR_TEST';
[~, trials] = m1_trials(noResponse, records, taskMatches);
assert(strcmp(trials(2).response_validity, 'missing_response') && isnan(trials(2).rt_ms));
groups = groups + 1;

% Exercise authoritative MAT and CSV exports, including unavailable values.
run = m1_log('new', root, 'offline_test');
run.status = 'offline_test'; run.messages = events; run.flips = taskFlips;
run.trials = trials; run.summary = summary;
run = m1_log('save', run, []);
saved = load(fullfile(run.folder, 'session.mat'));
assert(isequaln(saved.run.trials, trials));
csv = readtable(fullfile(run.folder, 'trials.csv'));
assert(height(csv) == 2 && isnan(csv.rt_ms(2)));
assert(isfile(fullfile(run.folder, 'messages.csv')) && ...
    isfile(fullfile(run.folder, 'optical_events.csv')));
groups = groups + 1;
% Scalar structures with empty character fields occur on very early aborts.
single = m1_log('new', root, 'offline_scalar_test');
single.messages = events(1); single.messages.label = '';
single.flips = taskFlips(1); single.flips.expected_edge = '';
single = m1_log('save', single, []);
assert(height(readtable(fullfile(single.folder, 'messages.csv'))) == 1);
assert(height(readtable(fullfile(single.folder, 'flips.csv'))) == 1);
groups = groups + 1;
fprintf('PASS: %d offline test groups; %d split positions.\n', groups, numel(stream) + 1);
fprintf('Test export: %s\n', run.folder);
end

function flips = make_flips(times)
flips = [];
for k = 1:numel(times)
    edge = 'R'; if mod(k, 2), edge = 'P'; end
    flips = [flips; struct('index', k, 'trial', ceil(k / 2), 'phase', 'test', ...
        'expected_edge', edge, 'scheduled_ptb', times(k), 'vbl_ptb', times(k), ...
        'onset_ptb', times(k), 'flip_end_ptb', times(k), 'missed_s', -0.001)]; %#ok<AGROW>
end
end
