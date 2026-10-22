function guard = m5_calibration_mask(action, window, rect)
%M5_CALIBRATION_MASK Blacken the sensor area before SDK calibration Flips.
% Screen is not reentrant: the pre-swap callback uses only OpenGL calls.
guard = [];
if strcmp(action, 'initialize')
    % MOGL imports GL/GLU into its caller; keep this outside the controller's
    % static nested workspace. Preserve the existing Screen preference.
    previous = Screen('Preference', 'Enable3DGraphics');
    guard = onCleanup(@() Screen('Preference', 'Enable3DGraphics', previous));
    InitializeMatlabOpenGL(0, 1, 1);
    return;
end
if strcmp(action, 'draw')
    glPushAttrib(hex2dec('84000')); % GL_SCISSOR_BIT | GL_COLOR_BUFFER_BIT.
    glEnable(3089); % GL_SCISSOR_TEST.
    glScissor(rect(1), rect(2), rect(3), rect(4));
    glColorMask(1, 1, 1, 1); glClearColor(0, 0, 0, 1);
    glClear(16384); % GL_COLOR_BUFFER_BIT.
    glPopAttrib;
    return;
end
hook = 'PreSwapbuffersOperations'; id = 'M5 calibration optical mask';
if strcmp(action, 'install')
    [~, height] = Screen('WindowSize', window);
    glRect = [rect(1), height-rect(4), rect(3)-rect(1), rect(4)-rect(2)];
    command = sprintf('m5_calibration_mask(''draw'', [], %s);', mat2str(glRect));
    Screen('HookFunction', window, 'AppendMFunction', hook, id, command);
    guard = onCleanup(@() m5_calibration_mask('remove', window, []));
    Screen('HookFunction', window, 'Enable', hook);
else
    try
        if ~ismember(window, Screen('Windows')), return; end
        slot = Screen('HookFunction', window, 'Query', hook, id);
        if slot >= 0, Screen('HookFunction', window, 'Remove', hook, slot); end
    catch
        % The owning display guard still closes a lost/invalid window safely.
    end
end
end
