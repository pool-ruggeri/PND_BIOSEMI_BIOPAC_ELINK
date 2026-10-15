function io = m1_wait(io, deadline)
%M1_WAIT Poll while waiting for a PTB deadline; never wait for a serial line.
while isempty(io.failure) && ~io.aborted
    io = tpad_io('poll', io);
    [~, ~, keys] = KbCheck;
    io.aborted = keys(KbName('ESCAPE'));
    remaining = deadline - GetSecs;
    if remaining <= 0, break; end
    WaitSecs('YieldSecs', min(0.001, remaining));
end
end
