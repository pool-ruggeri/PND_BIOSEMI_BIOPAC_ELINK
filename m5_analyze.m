function run = m5_analyze(run, io, records, flips, estate)
%M5_ANALYZE Block-scoped optical classification; global button release pairing.
% Raw acquisition is untouched. Receipt windows only select context; all RTs
% and pulse durations still use the original tPAD milliseconds and sequences.
messages = []; if ~isempty(io), messages = io.messages; end
run.raw_messages = messages;
[copy, matches, ~, pulses] = m1_match_optical(messages, [], 40, false, 0.25, 50);
context = zeros(1, numel(messages));
for b = 1:4
    first = run.blocks(b).acquisition_start_ptb; last = run.blocks(b).acquisition_end_ptb;
    if ~isfinite(last), last = Inf; end
    if isfinite(first) && ~isempty(messages)
        context([messages.rx_first_ptb] >= first & [messages.rx_first_ptb] < last) = b;
    end
end
for k=1:numel(pulses)
    pulses(k).block_number = 0; pulses(k).global_trial = 0; pulses(k).trial_in_block = 0;
end
for b=1:4
    indices = find(context==b);
    blockFlips = flips;
    if ~isempty(flips), blockFlips = flips([flips.trial]>(b-1)*10 & [flips.trial]<=b*10); end
    [part, found, ~, blockPulses] = m1_match_optical(copy(indices), blockFlips, ...
        10, strcmp(run.blocks(b).status,'COMPLETE'), 0.25, 50);
    copy(indices) = part; matches = [matches; found]; %#ok<AGROW>
    transitions = blockFlips;
    if ~isempty(transitions), transitions = transitions(~cellfun('isempty',{transitions.expected_edge})); end
    for k=1:numel(blockPulses)
        p = blockPulses(k);
        j = find([pulses.on_sequence]==p.on_sequence & [pulses.off_sequence]==p.off_sequence,1);
        if isempty(j), continue; end % Never create a pair absent from the raw sequence.
        pulses(j).classification = p.classification; pulses(j).block_number = b;
        trial = part(p.on_index).trial;
        pulses(j).global_trial = trial;
        if trial>0, pulses(j).trial_in_block=mod(trial-1,10)+1; end
        if p.transition_index > 0
            f = transitions(p.transition_index);
            pulses(j).transition_index = f.index;
        end
    end
end
for j=1:numel(copy)
    m=copy(j);
    if strcmp(m.channel,'A') && m.edge=='P' && ~startsWith(m.label,'SYNC_')
        t=find([records.fixation_ptb]<=m.rx_first_ptb,1,'last');
        if context(j)==0 || isempty(t) || ceil(t/10)~=context(j)
            copy(j).label='PRE_TRIAL_BLOCK_CONTEXT'; copy(j).trial=0;
        end
    end
end
[copy, trials] = m2_trials(copy, records, matches, run.targets);
for t=1:40
    trials(t).global_trial=t; trials(t).block_number=ceil(t/10);
    trials(t).trial_in_block=mod(t-1,10)+1;
end
for j=1:numel(copy)
    copy(j).acquisition_block=context(j); copy(j).block_number=context(j);
    copy(j).global_trial=copy(j).trial; copy(j).trial_in_block=0;
    if copy(j).trial > 0
        copy(j).block_number=ceil(copy(j).trial/10); copy(j).trial_in_block=mod(copy(j).trial-1,10)+1;
    end
end
for j=1:numel(flips)
    flips(j).global_trial=flips(j).trial; flips(j).trial_in_block=0; flips(j).block_number=0;
    if flips(j).trial>0
        flips(j).block_number=ceil(flips(j).trial/10); flips(j).trial_in_block=mod(flips(j).trial-1,10)+1;
    else
        for b=1:4
            if flips(j).onset_ptb>=run.blocks(b).acquisition_start_ptb && ...
                    (~isfinite(run.blocks(b).acquisition_end_ptb) || flips(j).onset_ptb<run.blocks(b).acquisition_end_ptb)
                flips(j).block_number=b;
            end
        end
    end
end
run.messages=copy; run.trials=trials; run.matches=matches; run.flips=flips;
run.optical_pulses=pulses; run.trial_boundaries=records; run.eyelink=estate;
run.calibrations=estate.calibrations;
for b=1:4
    row=summarize(trials((b-1)*10+(1:10)));
    row.valid_optical_pulses=0;
    if ~isempty(pulses)
        row.valid_optical_pulses=sum(strcmp({pulses.classification},'VALID_INTENDED_PULSE') & [pulses.block_number]==b);
    end
    row.block_number=b; row.status=run.blocks(b).status;
    row.calibration_accepted=estate.calibrations(b).accepted;
    row.sync_recorded=isfinite(run.sync(b).release_sequence);
    if b==1, run.block_summaries=row; else, run.block_summaries(b)=row; end
end
run.summary=summarize(trials); run.summary.planned_blocks=4;
run.summary.valid_optical_pulses=sum(strcmp({pulses.classification},'VALID_INTENDED_PULSE'));
run.summary.completed_blocks=sum(strcmp({run.blocks.status},'COMPLETE'));
run.summary.sync_count=sum(isfinite([run.sync.release_sequence]));
run.summary.sync_recorded=run.summary.sync_count==4;
rawOn=0; rawOff=0;
if ~isempty(messages)
    opto=strcmp({messages.channel},'C') & [messages.sensor]==1 & strcmp({messages.kind},'event');
    rawOn=sum(opto & strcmp({messages.edge},'P')); rawOff=sum(opto & strcmp({messages.edge},'R'));
end
run.optical_summary=struct('raw_on',rawOn,'raw_off',rawOff, ...
    'matched_on',run.summary.valid_optical_onsets,'matched_off',run.summary.valid_optical_offsets, ...
    'artifact_pairs',run.summary.optical_artifact_pairs, ...
    'missing_events',80-run.summary.valid_optical_onsets-run.summary.valid_optical_offsets);
end

function row = summarize(trials)
presented=isfinite([trials.stimulus_flip_ptb]);
correct=strcmp({trials.outcome},'CORRECT'); responded=ismember({trials.outcome},{'CORRECT','INCORRECT'});
row=struct('planned_trials',numel(trials),'presented_trials',sum(presented), ...
    'correct',sum(correct),'incorrect',sum(strcmp({trials.outcome},'INCORRECT')), ...
    'timeouts',sum(strcmp({trials.outcome},'TIMEOUT')), ...
    'valid_optical_onsets',sum(presented & ~[trials.missing_optical_on]), ...
    'valid_optical_offsets',sum(presented & ~[trials.missing_optical_off]), ...
    'valid_optical_pulses',sum(presented & ~[trials.missing_optical_on] & ~[trials.missing_optical_off]), ...
    'optical_artifact_pairs',sum([trials.optical_artifact_pairs]), ...
    'mean_correct_rt_ms',mean([trials(correct).rt_ms],'omitnan'), ...
    'mean_all_response_rt_ms',mean([trials(responded).rt_ms],'omitnan'));
end
