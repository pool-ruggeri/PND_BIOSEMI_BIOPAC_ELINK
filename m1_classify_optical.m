function messages = m1_classify_optical(messages, transitionContext)
%M1_CLASSIFY_OPTICAL Annotate, never delete, post-OFF optical bounce pairs.
% Timing tests use original hardware milliseconds only (20 ms gap, 5 ms ON).
% Signed gate indices: positive OFF, negative ON, zero outside receipt gates.
% Context protects intended transitions; it does not determine durations.
if isempty(messages), return; end
opto = strcmp({messages.kind}, 'event') & strcmp({messages.channel}, 'C') & ...
    [messages.sensor] == 1;
for j = 1:numel(messages)
    messages(j).optical_class = '';
    messages(j).optical_glitch = false;
    if opto(j)
        edge = 'OFF'; if messages(j).edge == 'P', edge = 'ON'; end
        validity = 'VALID';
        if messages(j).duplicate || messages(j).out_of_order || messages(j).state_error
            validity = 'INVALID';
        end
        messages(j).optical_class = [validity '_OPTICAL_' edge];
    end
end
indices = find(opto);
for k = 4:numel(indices)
    q = indices(k - 3:k);
    m = messages(q);
    % Require an intact preceding non-short pulse, then OFF -> extra ON/OFF.
    % Startup OFFs, missing edges, duplicates and reversed reports stay visible.
    if ~isequal([m.edge], 'PRPR') || any([m.duplicate] | [m.out_of_order] | ...
            [m.state_error] | [m.optical_glitch]), continue; end
    durations = diff([m.tpad_ms]);
    if durations(1) <= 5 || durations(2) < 0 || durations(2) > 20 || ...
            durations(3) < 0 || durations(3) > 5, continue; end
    % The anchor OFF and both extra edges must share one intended OFF gate.
    % Ambiguous onset bursts and reports outside a gate are never suppressed.
    off = transitionContext(q(2));
    if off <= 0 || transitionContext(q(1)) ~= -(off - 1) || ...
            any(transitionContext(q(3:4)) ~= off)
        continue;
    end
    messages(q(3)).optical_class = 'IGNORED_OPTICAL_GLITCH_ON';
    messages(q(4)).optical_class = 'IGNORED_OPTICAL_GLITCH_OFF';
    messages(q(3)).optical_glitch = true;
    messages(q(4)).optical_glitch = true;
end
end
