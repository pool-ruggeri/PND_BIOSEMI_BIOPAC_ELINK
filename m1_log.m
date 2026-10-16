function run = m1_log(action, varargin)
%M1_LOG Create a unique output directory or export a completed/partial run.
switch action
    case 'new'
        root = varargin{1}; name = varargin{2};
        folder = tempname(fullfile(root, 'data'));
        [~, token] = fileparts(folder);
        folder = fullfile(root, 'data', ...
            [name '_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '_' token]);
        [ok, msg] = mkdir(folder);
        assert(ok, 'M1:Logging', '%s', msg);
        run = struct('script', name, 'folder', folder, 'status', 'incomplete', ...
            'error', '', 'started_local', char(datetime('now')), ...
            'matlab_version', version, 'patch', [], 'ifi_s', NaN, ...
            'flips', [], 'sync', [], 'summary', [], 'trials', [], ...
            'messages', [], 'serial_failure', '', 'mode5_confirmed', false);
    case 'save'
        run = varargin{1}; io = varargin{2};
        if ~isempty(io)
            run.messages = io.messages;
            run.serial_failure = io.failure;
            run.mode5_confirmed = io.mode5Confirmed;
        end
        run.finished_local = char(datetime('now'));
        % MAT is authoritative and is saved before secondary CSV exports.
        save(fullfile(run.folder, 'session.mat'), 'run');
        if isfield(run, 'raw_messages') && ~isempty(run.raw_messages)
            writetable(struct2table(run.raw_messages, 'AsArray', true), ...
                fullfile(run.folder, 'raw_messages.csv'));
        end
        if isfield(run, 'optical_pulses') && ~isempty(run.optical_pulses)
            writetable(struct2table(run.optical_pulses, 'AsArray', true), ...
                fullfile(run.folder, 'optical_pulses.csv'));
        end
        if ~isempty(run.messages)
            writetable(struct2table(run.messages, 'AsArray', true), fullfile(run.folder, 'messages.csv'));
            events = run.messages(strcmp({run.messages.kind}, 'event') | ...
                strcmp({run.messages.kind}, 'unexpected'));
            if ~isempty(events)
                writetable(struct2table(events, 'AsArray', true), fullfile(run.folder, 'events.csv'));
                opto = events(strcmp({events.channel}, 'C') & [events.sensor] == 1);
                if ~isempty(opto)
                    writetable(struct2table(opto, 'AsArray', true), fullfile(run.folder, 'optical_events.csv'));
                end
            end
        end
        if ~isempty(run.flips)
            writetable(struct2table(run.flips, 'AsArray', true), fullfile(run.folder, 'flips.csv'));
        end
        if ~isempty(run.summary)
            writetable(struct2table(run.summary, 'AsArray', true), fullfile(run.folder, 'summary.csv'));
        end
        if ~isempty(run.trials)
            writetable(struct2table(run.trials, 'AsArray', true), fullfile(run.folder, 'trials.csv'));
        end
        if isfield(run, 'optical_summary')
            writetable(struct2table(run.optical_summary, 'AsArray', true), ...
                fullfile(run.folder, 'optical_summary.csv'));
        end
        if isfield(run, 'matches') && ~isempty(run.matches)
            writetable(struct2table(run.matches, 'AsArray', true), fullfile(run.folder, 'optical_matches.csv'));
        end
        fid = fopen(fullfile(run.folder, 'status.txt'), 'w');
        if fid >= 0
            guard = onCleanup(@() fclose(fid));
            fprintf(fid, 'Status: %s\nError: %s\nSerial failure: %s\n', ...
                run.status, run.error, run.serial_failure);
        end
    otherwise
        error('M1:Action', 'Unknown log action: %s', action);
end
end
