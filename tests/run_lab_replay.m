function summary = run_lab_replay
%RUN_LAB_REPLAY Read-only replay of the PO's 2026-10-16 physical run.
root = fileparts(fileparts(mfilename('fullpath')));
source = fullfile(root, 'data', ...
    'opto_50_cycles_20261016_101138_tp8074c4e9_ed58_4b9e_9dae_55037be1da10');
summary = [];
if ~isfolder(source)
    fprintf('SKIP: historical laboratory run is not present (data is Git-ignored).\n');
    return;
end
saved = load(fullfile(source, 'session.mat'));
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
% Re-decoding must reproduce every original record, not just optical totals.
fields = {'label', 'trial'};
assert(isequaln(rmfield(messages, fields), rmfield(saved.run.messages, fields)));
opto = messages(strcmp({messages.kind}, 'event') & ...
    strcmp({messages.channel}, 'C') & [messages.sensor] == 1);
durations = []; gaps = [];
for k = 2:numel(opto)
    if opto(k - 1).edge == 'P' && opto(k).edge == 'R'
        durations(end + 1) = opto(k).tpad_ms - opto(k - 1).tpad_ms; %#ok<AGROW>
        if k > 2 && opto(k - 2).edge == 'R'
            gaps(end + 1) = opto(k - 1).tpad_ms - opto(k - 2).tpad_ms; %#ok<AGROW>
        else
            gaps(end + 1) = NaN; %#ok<AGROW>
        end
    end
end
short = durations <= 5;
assert(sum(short) == 13 && min(durations(short)) == 1 && max(durations(short)) == 3);
assert(sum(short & gaps <= 20) == 11);
assert(isequal(sort(gaps(short & gaps > 20)), [495 496]));
[messages, matches, summary] = m1_match_optical(messages, saved.run.flips, ...
    50, strcmp(saved.run.status, 'complete'), 0.25, 50);
assert(summary.raw_detected_on == 63 && summary.raw_detected_off == 63);
assert(summary.ignored_glitch_pairs == 11);
assert(summary.detected_on == 52 && summary.detected_off == 52);
assert(summary.matched_on == 48 && summary.matched_off == 50);
assert(summary.missing_events == 2 && summary.unexpected_events == 6);
assert(strcmp(summary.result, 'FAIL'));
assert(isequal([matches(isnan([matches.tpad_ms])).trial], [22 23]));
% All original fields survive classification; only analysis labels/trials change.
assert(isequaln(rmfield(messages, [fields {'optical_class', 'optical_glitch'}]), ...
    rmfield(saved.run.messages, fields)));
replay = m1_log('new', fullfile(root, '.local', 'lab_replay'), 'historical_replay');
run = saved.run; run.folder = replay.folder;
run.replay_source = source; run.replay_only = true;
run.original_summary = saved.run.summary;
run.messages = messages; run.matches = matches; run.summary = summary;
run = m1_log('save', run, []);
fprintf(['PASS: historical replay regression (the recorded run still FAILS).\n' ...
    '13 short pulses: %.0f..%.0f ms; normal pulses: %.0f..%.0f ms.\n' ...
    '11 post-OFF pairs (gap %.0f..%.0f ms); 2 onset bursts retained (gap 495/496 ms).\n' ...
    'Raw: %d/%d; filtered: %d/%d; matched: %d/%d; missing: %d; unexpected: %d.\n' ...
    'Ambiguous intended ON: cycles 22 and 23. Replay export: %s\n'], ...
    min(durations(short)), max(durations(short)), ...
    min(durations(~short)), max(durations(~short)), ...
    min(gaps(short & gaps <= 20)), max(gaps(short & gaps <= 20)), ...
    summary.raw_detected_on, summary.raw_detected_off, ...
    summary.detected_on, summary.detected_off, summary.matched_on, summary.matched_off, ...
    summary.missing_events, summary.unexpected_events, run.folder);
end
