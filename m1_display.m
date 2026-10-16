function [window, rect, ifi] = m1_display(screenNumber)
%M1_DISPLAY Full screen with the caller's sync preference and RGB range 0..255.
AssertOpenGL;
[window, rect] = Screen('OpenWindow', screenNumber, [0 0 0]);
Screen('ColorRange', window, 255);
Screen('TextSize', window, 24);
ifi = Screen('GetFlipInterval', window);
KbName('UnifyKeyNames');
ListenChar(2);
HideCursor;
end
