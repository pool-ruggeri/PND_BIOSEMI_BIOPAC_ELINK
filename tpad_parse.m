function [state, messages] = tpad_parse(state, bytes, receivedPtb, finish)
%TPAD_PARSE Incremental Mode 5 text decoder; no PTB or hardware required.
% Empty state starts a stream. finish=true audits an unterminated fragment.
% rx_first_ptb/rx_complete_ptb describe host reads, never hardware event time.
if nargin < 4, finish = false; end
if isempty(state)
    state = struct('buffer', uint8([]), 'firstPtb', NaN, 'sequence', 0, ...
        'lastMs', -Inf, 'seen', {{}}, 'levels', NaN(4, 10), 'discarding', false);
end
template = struct('sequence', 0, 'kind', '', 'channel', '', 'edge', '', ...
    'sensor', NaN, 'tpad_ms', NaN, 'rx_first_ptb', NaN, ...
    'rx_complete_ptb', NaN, 'raw_hex', '', 'duplicate', false, ...
    'out_of_order', false, 'state_error', false, 'label', '', 'trial', 0);
messages = repmat(template, 0, 1);
bytes = uint8(bytes(:)');
% Process bytes rather than assuming a read is a message. CR and LF both
% terminate a line; the empty LF half of CRLF creates no extra message.
for b = bytes
    if isempty(state.buffer), state.firstPtb = receivedPtb; end
    if b == 10 || b == 13
        if ~isempty(state.buffer)
            emit('');
        end
        state.discarding = false;
    else
        state.buffer(end + 1) = b;
        if numel(state.buffer) >= 4096
            emit('malformed');
            % Continue logging but do not parse a suffix of an overlong line.
            state.discarding = true;
        end
    end
end
if finish && ~isempty(state.buffer), emit('incomplete'); end

    function emit(forcedKind)
        state.sequence = state.sequence + 1;
        m = template;
        m.sequence = state.sequence;
        m.rx_first_ptb = state.firstPtb;
        m.rx_complete_ptb = receivedPtb;
        m.raw_hex = strtrim(sprintf('%02X ', state.buffer));
        text = char(state.buffer);
        state.buffer = uint8([]);
        if ~isempty(forcedKind)
            m.kind = forcedKind;
        elseif state.discarding || any(double(text) > 127) || ...
                any(double(text) < 32 & double(text) ~= 9)
            m.kind = 'malformed';
        elseif ~isempty(regexp(text, '^MODE [0-6]:\s*$', 'once'))
            m.kind = 'mode';
            m.label = strtrim(text);
        elseif ~isempty(regexp(text, '^\d+\s*$', 'once'))
            m.kind = 'number'; % Firmware/query replies are not events.
            m.label = strtrim(text);
        elseif isempty(strtrim(text))
            m.kind = 'blank';
        else
            fields = regexp(strtrim(text), ...
                '^([A-Z])\s+([PR])\s+(\d+)\s+(\d+)$', 'tokens', 'once');
            if isempty(fields)
                m.kind = 'malformed';
            else
                m.channel = fields{1}; m.edge = fields{2};
                m.sensor = str2double(fields{3});
                m.tpad_ms = str2double(fields{4});
                stampDigits = regexprep(fields{4}, '^0+', '');
                if isempty(stampDigits), stampDigits = '0'; end
                channelIndex = find('ACMT' == m.channel, 1);
                limits = [10 2 1 1];
                if ~isfinite(m.tpad_ms) || m.tpad_ms > flintmax || ...
                        ~strcmp(sprintf('%.0f', m.tpad_ms), stampDigits) || ...
                        ~isfinite(m.sensor) || m.sensor > flintmax
                    m.kind = 'malformed';
                    m.tpad_ms = NaN;
                elseif isempty(channelIndex) || m.sensor < 1 || ...
                        m.sensor > limits(channelIndex)
                    m.kind = 'unexpected';
                else
                    m.kind = 'event';
                    identity = sprintf('%s %s %d %.0f', m.channel, m.edge, ...
                        m.sensor, m.tpad_ms);
                    level = double(m.edge == 'P');
                    % An intervening opposite edge makes a new transition,
                    % even when millisecond quantization repeats its identity.
                    m.duplicate = any(strcmp(state.seen, identity)) && ...
                        state.levels(channelIndex, m.sensor) == level;
                    state.seen{end + 1} = identity;
                    m.out_of_order = m.tpad_ms < state.lastMs;
                    state.lastMs = max(state.lastMs, m.tpad_ms);
                    m.state_error = ~m.duplicate && ...
                        state.levels(channelIndex, m.sensor) == level;
                    if ~m.duplicate && ~m.out_of_order
                        state.levels(channelIndex, m.sensor) = level;
                    end
                end
            end
        end
        messages(end + 1, 1) = m;
    end
end
