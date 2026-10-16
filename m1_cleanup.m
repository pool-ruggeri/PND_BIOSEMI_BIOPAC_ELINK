function m1_cleanup(io, restoreDisplay)
%M1_CLEANUP Best-effort cleanup, also safe during an exception.
if nargin < 2, restoreDisplay = true; end
if ~isempty(io)
    io.release(); % Shared, idempotent owner; handle 0 is valid while owned.
end
if restoreDisplay
    try
        Screen('CloseAll');
    catch
    end
    try
        ShowCursor;
    catch
    end
    try
        ListenChar(0);
    catch
    end
    try
        Priority(0);
    catch
    end
end
end
