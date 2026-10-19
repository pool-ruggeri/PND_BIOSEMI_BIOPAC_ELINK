function eye = m3_eyelink(folder, root)
%M3_EYELINK Shared owner for one real connection, EDF and continuous recording.
% No acquisition settings, clock transforms, serial commands or TTL writes.
recovery = fullfile(folder, 'eyelink_recovery.mat');
s = struct('host_basename', '', 'host_edf', '', 'run_id', '', 'local_edf', '', ...
    'filename_confirmed', false, 'calibration_accepted', false, ...
    'setup_result', NaN, 'calibration_result', NaN, 'calibration_text', '', ...
    'tracker_version', NaN, 'tracker_text', '', 'filters', struct, ...
    'versions', struct, 'connection_owned', false, 'file_may_be_open', false, ...
    'file_created', false, 'start_attempted', false, 'recording_confirmed', false, ...
    'stop_attempted', false, 'close_attempted', false, 'close_status', NaN, ...
    'shutdown_attempted', false, 'transfer_attempted', false, ...
    'transfer_bytes', NaN, 'local_bytes', NaN, 'transfer_verified', false, ...
    'trial_open', 0, 'task_exit_status', 'incomplete', 'failure', '', 'failures', {{}}, 'finished', false, ...
    'calls', struct('operation', {}, 'text', {}, 'start_ptb', {}, 'end_ptb', {}, ...
        'duration_s', {}, 'status', {}, 'error', {}), ...
    'poll_gaps', struct('operation', {}, 'before_ptb', {}, 'after_ptb', {}, 'gap_s', {}));
[~, s.run_id] = fileparts(folder);
eye = struct('initialize', @initialize, 'calibrate', @calibrate, 'start', @start, ...
    'message', @message, 'check', @check, 'state', @state, 'fail', @fail, ...
    'gap', @gap, 'finish', @finish, 'release', @release);
checkpoint;

    function initialize
        % Session-local startup only; never install/update or save MATLAB paths.
        if exist('PsychStartup', 'file'), PsychStartup; end
        for name = {'Screen', 'IOPort', 'Eyelink'}
            resolved = which(name{1}); [~, ~, ext] = fileparts(resolved);
            assert(strcmpi(ext, ['.' mexext]), 'M3:Preflight', ...
                '%s must resolve to its MATLAB MEX. Check PTB path and PsychStartup.', name{1});
            s.versions.(name{1}) = feval(name{1}, 'Version');
        end
        for name = {'EyelinkInitDefaults', 'EyelinkUpdateDefaults', ...
                'EyelinkDoTrackerSetup', 'PsychEyelinkDispatchCallback', 'InitializePsychSound'}
            assert(~isempty(which(name{1})), 'M3:Preflight', 'Missing %s.', name{1});
        end
        s.versions.edk = api('EDKVersion');
        assert(api('IsConnected') == 0, 'M3:Ownership', ...
            'An EyeLink connection already exists; this run will not take ownership.');
        s.connection_owned = true; % Own even a partially failed Initialize attempt.
        checkpoint;
        assert(api('Initialize', 'PsychEyelinkDispatchCallback') == 0, ...
            'M3:Connection', 'Real EyeLink initialization failed.');
        assert(api('IsConnected') == 1, 'M3:Connection', ...
            'Normal real EyeLink connection required; dummy/broadcast acquisition is rejected.');
        [s.tracker_version, s.tracker_text] = api('GetTrackerVersion');
        fprintf('EyeLink tracker: %s (type %d)\n', s.tracker_text, s.tracker_version);
        for name = {'file_sample_data', 'file_event_filter'}
            [status, reply] = api('ReadFromTracker', name{1});
            s.filters.(name{1}) = struct('status', status, 'reply', reply);
            checkpoint;
            assert(status == 0 && ~isempty(strtrim(reply)), 'M3:HostSettings', ...
                'Cannot verify Host %s. Operator/PO must inspect it; no setting was changed.', name{1});
        end
        require_tokens('file_sample_data', {'GAZE'});
        require_tokens('file_event_filter', {'FIXATION','SACCADE','BLINK','MESSAGE'});
        reserve_name;
        fprintf(['\nProposed Host EDF: %s\nLocal run: %s\n' ...
            'OpenFile can OVERWRITE a Host EDF. Inspect the Host file list first.\n'], ...
            s.host_edf, s.run_id);
        answer = input(sprintf('Type UNUSED %s only after confirming it is unused on the Host (anything else cancels): ', ...
            s.host_basename), 's');
        assert(strcmp(strtrim(answer), ['UNUSED ' s.host_basename]), 'M3:Abort', ...
            'Host filename safety not confirmed; no EDF was opened.');
        assert(~any(strcmpi(historical_names, s.host_basename)), 'M3:Filename', ...
            'Proposed EDF name is reserved in another local history; no EDF was opened.');
        s.filename_confirmed = true; s.file_may_be_open = true;
        checkpoint; % Mapping and confirmation persist BEFORE a create attempt.
        % The obsolete dontOpenExisting argument NEVER provided reliable safety.
        assert(api('OpenFile', s.host_edf) == 0, 'M3:EDFOpen', 'Host EDF creation failed.');
        s.file_created = true;
        assert(api('Command', sprintf('add_file_preamble_text "RECORDED BY numbered_circle_eyelink %s"', ...
            s.run_id)) == 0, 'M3:Command', 'EDF preamble command failed.');
        checkpoint;
    end

    function calibrate(window, patch)
        InitializePsychSound;
        el = EyelinkInitDefaults(window);
        el.backgroundcolour = patch.black; el.calibrationtargetcolour = patch.white;
        el.msgfontcolour = patch.white;
        EyelinkUpdateDefaults(el);
        [w, h] = Screen('WindowSize', window);
        assert(api('Command', sprintf('screen_pixel_coords = 0 0 %d %d', w-1, h-1)) == 0, ...
            'M3:Command', 'Screen coordinate command failed.');
        assert(message(sprintf('DISPLAY_COORDS 0 0 %d %d', w-1, h-1)), 'M3:Message', '%s', s.failure);
        began = GetSecs;
        try
            s.setup_result = EyelinkDoTrackerSetup(el);
        catch problem
            log_call('TrackerSetup', '', began, NaN, problem.message); rethrow(problem);
        end
        log_call('TrackerSetup', '', began, s.setup_result, '');
        assert(s.setup_result == 0 && api('IsConnected') == 1, ...
            'M3:Calibration', 'EyeLink setup failed or connection was lost.');
        try
            [s.calibration_result, s.calibration_text] = api('CalMessage');
        catch problem
            s.calibration_text = ['Result unavailable: ' problem.message];
        end
        checkpoint;
        Screen('FillRect', window, patch.black);
        DrawFormattedText(window, sprintf(['Review calibration AND validation on the Host.\n%s\n\n' ...
            'Press Y only if quality is acceptable; ESC cancels.'], s.calibration_text), ...
            'center', 'center', patch.white);
        Screen('FillRect', window, patch.black, patch.rect); Screen('Flip', window);
        KbReleaseWait;
        while true
            [~, ~, keys] = KbCheck;
            assert(~keys(KbName('ESCAPE')), 'M3:Abort', 'Calibration/validation acceptance cancelled.');
            if keys(KbName('y')), break; end
            WaitSecs('YieldSecs', 0.01);
        end
        s.calibration_accepted = true; checkpoint;
        ListenChar(2);
        Screen('FillRect', window, patch.black); Screen('Flip', window);
    end

    function start
        assert(s.calibration_accepted && s.file_created && s.trial_open == 1 && ~s.start_attempted, ...
            'M3:Order', 'Calibration, owned EDF and first TRIALID required before the single recording.');
        api('SetOfflineMode');
        s.start_attempted = true; checkpoint;
        assert(api('StartRecording', 1, 1, 0, 0) == 0, 'M3:Recording', 'StartRecording failed.');
        s.recording_confirmed = true; checkpoint;
    end

    function ok = check
        ok = false;
        try
            assert(api('CheckRecording') == 0, 'M3:Recording', 'EyeLink recording interrupted.');
            ok = true;
        catch problem
            fail(problem);
        end
    end

    function ok = message(text)
        ok = false;
        try
            assert(numel(text) <= 240 && ~contains(text, newline), 'M3:Message', 'Invalid message length/line.');
            if startsWith(text, 'TRIALID ')
                assert(s.trial_open == 0, 'M3:Order', 'Previous Data Viewer trial is still open.');
            end
            assert(api('Message', '%s', text) == 0, 'M3:Message', 'EyeLink message submission failed.');
            if startsWith(text, 'TRIALID '), s.trial_open = sscanf(text, 'TRIALID %d', 1); end
            if startsWith(text, 'TRIAL_RESULT '), s.trial_open = 0; end
            ok = true;
        catch problem
            fail(problem);
        end
    end

    function finish(status)
        if s.finished, return; end
        s.finished = true; % Shared guard cannot repeat stop/close/shutdown.
        s.task_exit_status = status;
        if s.connection_owned
            if s.recording_confirmed
                if s.trial_open > 0
                    result = -1; if strcmp(status, 'aborted'), result = 3; end
                    message(sprintf('TRIAL_RESULT %d', result));
                end
                message(['SESSION_END status=' upper(status)]);
                try
                    WaitSecs(0.1); % Eye-only tail; serial data was saved first.
                catch problem
                    fail(problem);
                end
            end
            if s.start_attempted
                s.stop_attempted = true; attempt('StopRecording');
            end
            attempt('SetOfflineMode');
            if s.file_may_be_open
                s.close_attempted = true;
                try
                    s.close_status = api('CloseFile');
                    assert(s.close_status == 0, 'M3:EDFClose', 'CloseFile returned %g.', s.close_status);
                catch problem
                    fail(problem);
                end
                s.file_may_be_open = false;
                if s.close_status == 0
                    s.transfer_attempted = true;
                    try
                        assert(~isfile(s.local_edf), 'M3:Destination', ...
                            'Local EDF destination exists; retained without overwriting: %s', s.local_edf);
                        s.transfer_bytes = api('ReceiveFile', s.host_edf, s.local_edf, 0);
                        info = dir(s.local_edf);
                        if ~isempty(info), s.local_bytes = info.bytes; end
                        assert(s.transfer_bytes > 0 && s.local_bytes == s.transfer_bytes, ...
                            'M3:Transfer', 'EDF transfer failed/cancelled or byte count differs. Host original retained.');
                        s.transfer_verified = true;
                    catch problem
                        fail(problem);
                    end
                end
            end
            s.shutdown_attempted = true; attempt('Shutdown');
            s.connection_owned = false;
        end
        checkpoint;
    end

    function release
        if ~s.finished
            try
                finish('error');
            catch problem
                fprintf(2, 'EyeLink cleanup: %s\n', problem.message);
            end
        end
    end

    function value = state
        value = s;
    end

    function fail(problem)
        if isempty(s.failure), s.failure = problem.message; end
        s.failures{end+1} = problem.message;
    end

    function gap(operation, before, after)
        s.poll_gaps(end+1) = struct('operation', operation, 'before_ptb', before, ...
            'after_ptb', after, 'gap_s', after-before);
        if after-before >= 0.25
            fail(MException('M3:Timing', ...
                'EyeLink %s interrupted serial polling for %.3f s (250 ms optical gate unchanged).', ...
                operation, after-before));
        end
    end

    function varargout = api(operation, varargin)
        began = GetSecs; text = '';
        if strcmp(operation, 'Message'), text = varargin{2};
        elseif ~isempty(varargin) && ischar(varargin{1}), text = varargin{1}; end
        try
            [varargout{1:nargout}] = Eyelink(operation, varargin{:});
        catch problem
            log_call(operation, text, began, NaN, problem.message); rethrow(problem);
        end
        result = NaN;
        if nargout && isnumeric(varargout{1}) && isscalar(varargout{1}), result = varargout{1}; end
        log_call(operation, text, began, result, '');
    end

    function log_call(operation, text, began, result, problem)
        ended = GetSecs;
        s.calls(end+1) = struct('operation', operation, 'text', text, ...
            'start_ptb', began, 'end_ptb', ended, 'duration_s', ended-began, ...
            'status', result, 'error', problem);
    end

    function attempt(operation)
        try
            api(operation);
        catch problem
            fail(problem);
        end
    end

    function require_tokens(name, required)
        tokens = regexp(upper(s.filters.(name).reply), '[A-Z]+', 'match');
        missing = required(~ismember(required, tokens));
        assert(isempty(missing), 'M3:HostSettings', ...
            'Host %s lacks %s. Stop: operator/PO approval is required for any correction; settings were not changed.', ...
            name, strjoin(missing, ','));
    end

    function reserve_name
        used = historical_names;
        for k = 1:128
            token = upper(strrep(char(java.util.UUID.randomUUID), '-', ''));
            candidate = ['E' token(1:7)];
            if ~any(strcmpi(used, candidate))
                s.host_basename = candidate; s.host_edf = [candidate '.edf'];
                s.local_edf = fullfile(folder, s.host_edf); checkpoint; return;
            end
        end
        error('M3:Filename', 'Could not reserve an unused local EDF name; no Host file opened.');
    end

    function names = historical_names
        names = {};
        files = dir(fullfile(root, 'data', '**', 'eyelink_recovery.mat'));
        for k = 1:numel(files)
            file = fullfile(files(k).folder, files(k).name);
            if strcmpi(file, recovery), continue; end
            prior = load(file, 'eyelink'); % Corrupt history fails closed.
            assert(isfield(prior, 'eyelink') && isfield(prior.eyelink, 'host_basename'), ...
                'M3:Filename', 'Unverifiable local EDF history: %s', file);
            names{end+1} = prior.eyelink.host_basename; %#ok<AGROW>
        end
        files = dir(fullfile(root, 'data', '**', '*.edf'));
        for k = 1:numel(files)
            [~, name] = fileparts(files(k).name); names{end+1} = name; %#ok<AGROW>
        end
    end

    function checkpoint
        eyelink = s;
        save(recovery, 'eyelink');
    end
end
