function m1_cleanup(io, restoreDisplay)
%M1_CLEANUP Best-effort cleanup, also safe during an exception.
if nargin < 2, restoreDisplay = true; end
if ~isempty(io)
    if ~isempty(io.handle) && io.handle >= 0
        try
            IOPort('Close', io.handle);
        catch
        end
    end
    for fid = [io.rawFid io.chunkFid io.txFid]
        if fid >= 0
            try
                fclose(fid);
            catch
            end
        end
    end
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
