function varargout = m5_setup_callback(varargin)
%M5_SETUP_CALLBACK Keep the existing serial reader polled during SDK setup.
% Graphics, camera, sounds and keyboard handling remain the official callback.
persistent poller
if ischar(varargin{1}) && strcmp(varargin{1}, 'poller')
    poller = varargin{2}; return;
elseif ischar(varargin{1}) && strcmp(varargin{1}, 'clear')
    poller = []; return;
end
if ~isempty(poller), poller(); end
[varargout{1:nargout}] = PsychEyelinkDispatchCallback(varargin{:});
if ~isempty(poller), poller(); end
end
