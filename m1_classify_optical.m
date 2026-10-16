function [messages, pulses] = m1_classify_optical(messages, context, intendedMs, toleranceMs)
%M1_CLASSIFY_OPTICAL Retain complete pulses and annotate transition chatter.
% All measured durations/gaps use original hardware ms, in serial order.
% Signed receipt gates protect intended transitions: negative ON, positive OFF.
template = struct('on_index', 0, 'off_index', 0, 'on_sequence', 0, ...
    'off_sequence', 0, 'on_ms', NaN, 'off_ms', NaN, 'duration_ms', NaN, ...
    'transition_index', 0, 'classification', 'UNRESOLVED_PULSE');
pulses = repmat(template, 0, 1);
if isempty(messages), return; end
if nargin < 3, intendedMs = 500 * ones(1, max(abs(context))); end
if nargin < 4, toleranceMs = 50; end
opto = strcmp({messages.kind}, 'event') & strcmp({messages.channel}, 'C') & ...
    [messages.sensor] == 1;
for j = 1:numel(messages)
    messages(j).optical_class = '';
    messages(j).optical_glitch = false;
    if opto(j)
        edge = 'OFF'; if messages(j).edge == 'P', edge = 'ON'; end
        validity = 'UNRESOLVED';
        if messages(j).duplicate || messages(j).out_of_order || messages(j).state_error
            validity = 'INVALID';
        end
        messages(j).optical_class = [validity '_OPTICAL_' edge];
    end
end
indices = find(opto);
for k = 1:numel(indices) - 1
    q = indices(k:k + 1); m = messages(q);
    if ~isequal([m.edge], 'PR'), continue; end
    p = template;
    p.on_index = q(1); p.off_index = q(2);
    p.on_sequence = m(1).sequence; p.off_sequence = m(2).sequence;
    p.on_ms = m(1).tpad_ms; p.off_ms = m(2).tpad_ms;
    p.duration_ms = p.off_ms - p.on_ms;
    on = -context(q(1));
    if ~any([m.duplicate] | [m.out_of_order] | [m.state_error]) && ...
            p.duration_ms >= 0 && on > 0 && context(q(2)) == on + 1 && ...
            abs(p.duration_ms - intendedMs(on)) <= toleranceMs
        p.classification = 'VALID_INTENDED_PULSE';
        p.transition_index = on;
        messages(q(1)).optical_class = 'VALID_OPTICAL_ON';
        messages(q(2)).optical_class = 'VALID_OPTICAL_OFF';
    end
    pulses(end + 1, 1) = p; %#ok<AGROW>
end
% Only complete short pairs next to a recovered intended pulse can be chatter.
% Walk whole bursts, so repeated pairs and equal-ms ON/OFF/ON are supported.
for anchor = 1:numel(pulses)
    a = pulses(anchor);
    if ~strcmp(a.classification, 'VALID_INTENDED_PULSE') || a.duration_ms <= 3
        continue;
    end
    for direction = [-1 1]
        adjacent = anchor; candidate = anchor + direction;
        while candidate >= 1 && candidate <= numel(pulses)
            p = pulses(candidate); q = [p.on_index p.off_index]; m = messages(q);
            if ~strcmp(p.classification, 'UNRESOLVED_PULSE') || ...
                    p.duration_ms < 0 || p.duration_ms > 3 || ...
                    any([m.duplicate] | [m.out_of_order] | [m.state_error])
                break;
            end
            if direction < 0
                touching = find(indices == pulses(adjacent).on_index) - ...
                    find(indices == p.off_index) == 1;
                gap = pulses(adjacent).on_ms - p.off_ms;
                span = a.on_ms - p.on_ms;
                gate = -a.transition_index; position = 'ONSET';
            else
                touching = find(indices == p.on_index) - ...
                    find(indices == pulses(adjacent).off_index) == 1;
                gap = p.on_ms - pulses(adjacent).off_ms;
                span = p.off_ms - a.off_ms;
                gate = a.transition_index + 1; position = 'OFFSET';
            end
            if ~touching || gap < 0 || span < 0 || span > 20 || ...
                    any(context(q) ~= gate), break; end
            pulses(candidate).classification = ['SHORT_ARTIFACT_' position];
            messages(q(1)).optical_class = 'IGNORED_OPTICAL_GLITCH_ON';
            messages(q(2)).optical_class = 'IGNORED_OPTICAL_GLITCH_OFF';
            messages(q(1)).optical_glitch = true;
            messages(q(2)).optical_glitch = true;
            adjacent = candidate; candidate = candidate + direction;
        end
    end
end
end
