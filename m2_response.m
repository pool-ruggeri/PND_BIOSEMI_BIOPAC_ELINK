function [index, verified] = m2_response(messages, record, onsetMs, onsetSequence, limitPtb)
%M2_RESPONSE First fresh serial B1..B4 press; clocks never share an epoch.
% Available hardware anchors enforce 0..1500 ms, including during serial grace.
% Otherwise a receipt-window candidate is explicitly unverified (RT stays NaN).
index = NaN; verified = false;
for j = 1:numel(messages)
    m = messages(j);
    if ~strcmp(m.kind, 'event') || ~strcmp(m.channel, 'A') || ...
            ~ismember(m.sensor, 1:4) || m.edge ~= 'P' || m.duplicate || ...
            m.out_of_order || m.state_error || startsWith(m.label, 'SYNC_') || ...
            startsWith(m.label, 'PRE_TRIAL') || m.sequence <= record.start_sequence || ...
            m.rx_complete_ptb < record.onset_ptb || m.rx_complete_ptb > limitPtb
        continue;
    end
    if isfinite(onsetMs) && isfinite(onsetSequence)
        elapsed = m.tpad_ms - onsetMs;
        eligible = m.sequence > onsetSequence && elapsed >= 0 && elapsed <= 1500;
    else
        eligible = m.rx_first_ptb >= record.onset_ptb && ...
            m.rx_first_ptb <= record.response_deadline_ptb;
    end
    if eligible
        index = j; verified = isfinite(onsetMs) && isfinite(onsetSequence);
        return;
    end
end
end
