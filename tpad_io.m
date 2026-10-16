function io = tpad_io(action, io, varargin)
%TPAD_IO Small IOPort reader. Call open, poll, drain, finish, then close.
% Failures are returned in io.failure so acquired data survives exceptions.
switch action
    case 'open'
        port = varargin{1}; folder = varargin{2};
        io = struct('handle', [], 'rawFid', -1, 'chunkFid', -1, 'txFid', -1, ...
            'parser', [], 'messages', [], 'offset', 0, 'failure', '', ...
            'aborted', false, 'mode5Confirmed', false, 'port', port);
        [io.own, io.release] = resource_owner;
        try
            io.rawFid = fopen(fullfile(folder, 'raw_rx.bin'), 'wb');
            io.own('file', io.rawFid);
            io.chunkFid = fopen(fullfile(folder, 'raw_chunks.csv'), 'w');
            io.own('file', io.chunkFid);
            io.txFid = fopen(fullfile(folder, 'commands.csv'), 'w');
            io.own('file', io.txFid);
            assert(all([io.rawFid io.chunkFid io.txFid] >= 0), ...
                'M1:Logging', 'Cannot open serial journals.');
            fprintf(io.chunkFid, 'byte_offset,byte_count,read_complete_ptb,poll_ptb\n');
            fprintf(io.txFid, 'host_ptb,raw_hex\n');
            config = ['BaudRate=115200 DataBits=8 Parity=None StopBits=1 ' ...
                'FlowControl=None Terminator=-1 ReadTimeout=0.001 ' ...
                'SendTimeout=0.1 InputBufferSize=65536'];
            [io.handle, err] = IOPort('OpenSerialPort', port, config);
            io.own('port', io.handle);
            assert(isempty(err) && io.handle >= 0, 'M1:SerialOpen', '%s', err);
            % No Purge: every byte read, including setup replies, is retained.
            io = send_command(io, uint8('X'));
            io = await_mode(io, 'MODE 0:');
            if ~isempty(io.failure), return; end
            WaitSecs(0.025); % Manufacturer requires >=25 ms between commands.
            io = send_command(io, uint8(sprintf('MOD5\r\n')));
            io = await_mode(io, 'MODE 5:');
            io.mode5Confirmed = isempty(io.failure);
        catch problem
            io.failure = problem.message;
        end
    case 'poll'
        if isempty(io.handle) || ~isempty(io.failure), return; end
        try
            [bytes, when, err] = IOPort('Read', io.handle, 0, 4096);
            polled = GetSecs;
            % Preserve returned bytes even when IOPort also reports an error.
            if ~isempty(bytes)
                n = fwrite(io.rawFid, uint8(bytes), 'uint8');
                assert(n == numel(bytes), 'M1:Logging', 'Short raw journal write.');
                fprintf(io.chunkFid, '%.0f,%d,%.9f,%.9f\n', ...
                    io.offset, n, when, polled);
                io.offset = io.offset + n;
                [io.parser, messages] = tpad_parse(io.parser, bytes, polled);
                io.messages = [io.messages; messages];
            end
            assert(isempty(err), 'M1:SerialRead', '%s', err);
        catch problem
            io.failure = problem.message;
        end
    case 'drain'
        deadline = GetSecs + varargin{1};
        while GetSecs < deadline && isempty(io.failure)
            io = tpad_io('poll', io);
            WaitSecs('YieldSecs', 0.001);
        end
        io = tpad_io('poll', io);
    case 'finish'
        [io.parser, messages] = tpad_parse(io.parser, [], GetSecs, true);
        io.messages = [io.messages; messages];
    case 'close'
        m1_cleanup(io, false);
        io.handle = []; io.rawFid = -1; io.chunkFid = -1; io.txFid = -1;
    otherwise
        error('M1:Action', 'Unknown serial action: %s', action);
end
end

function [own, release] = resource_owner
% Nested handles share ownership even in the onCleanup snapshot of io.
% Clear ownership before closing, so repeated cleanup cannot close a reused ID.
port = []; files = [];
own = @adopt; release = @close_owned;
    function adopt(kind, value)
        if isempty(value) || value < 0, return; end
        if strcmp(kind, 'port')
            port = value; % Zero is a valid IOPort handle.
        else
            files(end + 1) = value;
        end
    end
    function close_owned
        handle = port; port = [];
        if ~isempty(handle)
            try
                IOPort('Close', handle);
            catch
            end
        end
        ownedFiles = files; files = [];
        for fid = ownedFiles
            try
                fclose(fid);
            catch
            end
        end
    end
end

function io = send_command(io, bytes)
% Only initialization writes exist. Never echo events or reset the clock.
assert(isequal(bytes, uint8('X')) || ...
    isequal(bytes, uint8(sprintf('MOD5\r\n'))), 'M1:Command', 'Unsupported command.');
fprintf(io.txFid, '%.9f,%s\n', GetSecs, strtrim(sprintf('%02X ', bytes)));
[n, ~, err] = IOPort('Write', io.handle, bytes, 1);
assert(isempty(err) && n == numel(bytes), 'M1:SerialWrite', ...
    'Serial command failed or was incomplete: %s', err);
end

function io = await_mode(io, label)
deadline = GetSecs + 2;
while GetSecs < deadline && isempty(io.failure)
    io = tpad_io('poll', io);
    if ~isempty(io.messages) && any(strcmp({io.messages.label}, label)), return; end
    [~, ~, keys] = KbCheck;
    if keys(KbName('ESCAPE'))
        io.aborted = true; io.failure = 'Aborted during tPAD initialization.'; return;
    end
    WaitSecs('YieldSecs', 0.001);
end
if isempty(io.failure), io.failure = ['No acknowledgement: ' label]; end
end
