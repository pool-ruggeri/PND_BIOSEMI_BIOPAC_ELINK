function [window, rect, ifi] = m1_display(screenNumber, patch)
%M1_DISPLAY Full screen with PTB timing checks enabled and RGB range 0..255.
AssertOpenGL;
Screen('Preference', 'SkipSyncTests', 0);
[window, rect] = Screen('OpenWindow', screenNumber, [0 0 0]);
Screen('ColorRange', window, 255);
Screen('TextSize', window, 24);
ifi = Screen('GetFlipInterval', window);
if nargin > 1 && ~isempty(patch)
    assert(isequal(patch.resolution, rect(3:4)), 'M1:Display', ...
        'Display resolution changed. Repeat opto_calibration.');
    r = patch.rect;
    assert(numel(r) == 4 && all(isfinite(r)) && all(r(1:2) >= 0) && ...
        all(r(3:4) <= rect(3:4)) && all(r(3:4) > r(1:2)), ...
        'M1:Display', 'Invalid optical patch rectangle. Repeat calibration.');
end
KbName('UnifyKeyNames');
ListenChar(2);
HideCursor;
end
