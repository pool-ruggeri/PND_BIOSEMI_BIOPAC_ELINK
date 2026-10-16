function summaries = run_lab_replay
%RUN_LAB_REPLAY Read-only raw replay; fixture expectations never drive analysis.
root = fileparts(fileparts(mfilename('fullpath')));
names = {'opto_50_cycles_20261016_105138_tp4904ffea_6e55_43ed_a961_4b0a28b01c2d', ...
    'opto_50_cycles_20261016_115133_tp22f4ba43_8327_4209_acda_31dda354e243', ...
    'opto_50_cycles_20261016_101138_tp8074c4e9_ed58_4b9e_9dae_55037be1da10'};
% Assertions describe the three immutable fixtures, not filter parameters.
rawCounts = [61 55 63]; artifacts = [11 5 13]; onsetArtifacts = [2 1 2];
durationRanges = [502 505; 502 506; 501 504]; missed = [1 1 0];
summaries = [];
for fixture = 1:numel(names)
    source = fullfile(root, 'data', names{fixture});
    if ~isfolder(source)
        fprintf('SKIP: Git-ignored laboratory recording absent: %s\n', names{fixture});
        continue;
    end
    saved = load(fullfile(source, 'session.mat'));
    messages = decode_raw(source);
    core = {'sequence', 'kind', 'channel', 'edge', 'sensor', 'tpad_ms', ...
        'rx_first_ptb', 'rx_complete_ptb', 'raw_hex', 'out_of_order'};
    assert(isequaln(select_fields(messages, core), select_fields(saved.run.messages, core)));
    % Only duplicate/state annotations change: raw bytes and all timestamps agree.
    assert(~any([messages.duplicate] | [messages.state_error] | [messages.out_of_order]));
    rawMessages = messages;
    [messages, matches, s, pulses] = m1_match_optical(messages, saved.run.flips, ...
        50, strcmp(saved.run.status, 'complete'), 0.25, 50);
    assert(s.raw_detected_on == rawCounts(fixture) && s.raw_detected_off == rawCounts(fixture));
    assert(s.ignored_glitch_pairs == artifacts(fixture));
    assert(s.detected_on == 50 && s.detected_off == 50 && s.recovered_pulses == 50);
    assert(s.matched_on == 50 && s.matched_off == 50);
    assert(s.missing_events == 0 && s.missing_pulses == 0 && s.unexpected_events == 0);
    assert(strcmp(s.pulse_recovery_result, 'PASS') && s.missed_flip_deadlines == missed(fixture));
    assert(strcmp(s.result, 'PASS') == (missed(fixture) == 0));
    assert(isequal([s.duration_min_ms s.duration_max_ms], durationRanges(fixture, :)));
    onsetCount = sum(strcmp({pulses.classification}, 'SHORT_ARTIFACT_ONSET'));
    offsetCount = sum(strcmp({pulses.classification}, 'SHORT_ARTIFACT_OFFSET'));
    assert(onsetCount == onsetArtifacts(fixture));
    short = pulses(startsWith({pulses.classification}, 'SHORT_ARTIFACT_'));
    assert(all([short.duration_ms] >= 0 & [short.duration_ms] <= 3));
    assert(isequaln(select_fields(messages, core), select_fields(rawMessages, core)));
    replay = m1_log('new', fullfile(root, '.local', 'lab_replay'), 'historical_replay');
    run = saved.run; run.folder = replay.folder;
    run.replay_source = source; run.replay_only = true;
    run.original_summary = saved.run.summary; run.raw_messages = rawMessages;
    run.messages = messages; run.matches = matches; run.summary = s; run.optical_pulses = pulses;
    run = m1_log('save', run, []);
    assert(isfile(fullfile(run.folder, 'raw_messages.csv')));
    assert(height(readtable(fullfile(run.folder, 'optical_pulses.csv'))) == numel(pulses));
    summaries = [summaries; s]; %#ok<AGROW>
    fprintf(['PASS replay: %s\nRaw %d/%d; valid %d/%d; short artifacts %d (ONSET %d/OFFSET %d), %.0f..%.0f ms.\n' ...
        'Recovered %d pulses, %.0f..%.0f ms; missing %d; unresolved %d; pulse recovery %s.\n' ...
        'Full checks %s: %d missed flip(s). Original duplicate/state flags %d/%d -> %d/%d.\n' ...
        'Raw artifacts remain a physical qualification issue. Replay: %s\n'], ...
        names{fixture}, s.raw_detected_on, s.raw_detected_off, s.matched_on, s.matched_off, ...
        s.ignored_glitch_pairs, onsetCount, offsetCount, ...
        min([short.duration_ms]), max([short.duration_ms]), s.recovered_pulses, ...
        s.duration_min_ms, s.duration_max_ms, s.missing_pulses, s.unexpected_events, ...
        s.pulse_recovery_result, s.result, s.missed_flip_deadlines, ...
        sum([saved.run.messages.duplicate]), sum([saved.run.messages.state_error]), ...
        sum([rawMessages.duplicate]), sum([rawMessages.state_error]), run.folder);
end
end

function messages = decode_raw(source)
fid = fopen(fullfile(source, 'raw_rx.bin'), 'rb'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid));
raw = fread(fid, Inf, '*uint8')';
chunks = readtable(fullfile(source, 'raw_chunks.csv'));
state = []; messages = []; offset = 0;
for k = 1:height(chunks)
    assert(chunks.byte_offset(k) == offset, 'Raw journal has a gap/overlap.');
    n = chunks.byte_count(k);
    [state, m] = tpad_parse(state, raw(offset + (1:n)), chunks.poll_ptb(k));
    messages = [messages; m]; %#ok<AGROW>
    offset = offset + n;
end
assert(offset == numel(raw));
[~, tail] = tpad_parse(state, [], chunks.poll_ptb(end), true);
messages = [messages; tail];
end

function selected = select_fields(messages, fields)
selected = rmfield(messages, setdiff(fieldnames(messages), fields));
end
