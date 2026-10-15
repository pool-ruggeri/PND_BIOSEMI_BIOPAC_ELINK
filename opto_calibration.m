% Position and resize an optical patch in pixels; no serial connection needed.
screenNumber = max(Screen('Screens'));
initialSizePx = 150;
moveStepPx = 5;
resizeStepPx = 10;
calibrate_patch(fileparts(mfilename('fullpath')), screenNumber, ...
    initialSizePx, moveStepPx, resizeStepPx);

function calibrate_patch(root, screenNumber, initialSize, step, resizeStep)
AssertOpenGL;
oldShield = Screen('Preference', 'WindowShieldingLevel');
oldSync = Screen('Preference', 'SkipSyncTests');
cleanup = onCleanup(@() close_calibration(oldShield, oldSync));
Screen('Preference', 'WindowShieldingLevel', 0); % Normal stacking, not topmost.
Screen('Preference', 'SkipSyncTests', 2); % This GUI does not measure timing.
screenRect = Screen('Rect', screenNumber);
screenGlobal = Screen('GlobalRect', screenNumber);
resolution = screenRect(3:4) - screenRect(1:2);
windowSize = min([700 500], resolution - 80);
windowPosition = min([60 60], resolution - windowSize);
file = fullfile(root, 'opto_patch.mat');
oldPatch = [];
if isfile(file)
    old = load(file, 'patch');
    if isfield(old, 'patch') && old.patch.screen == screenNumber && ...
            isequal(old.patch.resolution, resolution) && ...
            numel(old.patch.rect) == 4 && all(isfinite(old.patch.rect)) && ...
            all(old.patch.rect(3:4) > old.patch.rect(1:2))
        oldPatch = old.patch;
        windowPosition = min(max(oldPatch.rect(1:2) - [40 60], [0 0]), resolution - windowSize);
    end
end
origin = screenGlobal(1:2) + windowPosition;
[window, ~] = Screen('OpenWindow', screenNumber, [0 0 0], ...
    [origin origin + windowSize], [], [], [], [], [], kPsychGUIWindow);
Screen('ColorRange', window, 255);
KbName('UnifyKeyNames');
ListenChar(0); % Leave keyboard interaction with the BBTK app available.
ShowCursor('Arrow', window);
rect = Screen('Rect', window);
windowGlobal = Screen('GlobalRect', window);
patch = struct('version', 1, 'screen', screenNumber, 'resolution', resolution, ...
    'black', [0 0 0], 'white', [255 255 255], 'rect', [], ...
    'size_px', [], 'saved_local', '');
side = min(initialSize, min(rect(3:4)));
position = min([20 20], rect(3:4) - side);
if ~isempty(oldPatch)
    side = min(max(1, round(max(oldPatch.rect(3:4) - oldPatch.rect(1:2)))), min(rect(3:4)));
    position = oldPatch.rect(1:2) + screenGlobal(1:2) - windowGlobal(1:2);
end
position = min(max(round(position), [0 0]), rect(3:4) - side);
patch.rect = [position position + side]; patch.size_px = [side side];
keyNames = KbName('KeyNames');
% PTB 3.0.19 uses numeric [] for unnamed keys; cell/ismember rejects those.
isText = cellfun(@(name) ischar(name) && (isrow(name) || isempty(name)), keyNames);
keyNames(~isText) = {''};
saveKeys = ismember(keyNames, {'Return', 'ENTER', 'enter'});
growKeys = ismember(keyNames, {'=+', '+', 'Add'});
shrinkKeys = ismember(keyNames, {'-_', '-', 'Subtract'});
[~, ~, initialKeys] = KbCheck;
previousSave = any(initialKeys(saveKeys)); % Ignore ENTER held from launching.
white = true; previousSpace = false; previousGrow = false; previousShrink = false;
previousMouse = false; dragging = false; dragOffset = [0 0]; nextMove = 0;
fprintf('Drag or arrows: move; +/-: resize; SPACE: black/white; ENTER: save; ESC: abort.\n');
fprintf('Use the BBTK app to adjust sensitivity; this script does not set it.\n');
Screen('FillRect', window, patch.black);
Screen('FillRect', window, patch.white, patch.rect);
Screen('Flip', window);
while true
    [~, now, keys] = KbCheck;
    [mx, my, buttons, focused] = GetMouse(window);
    if ~focused
        % BBTK keystrokes must not move, toggle, save, or cancel calibration.
        dragging = false; previousMouse = buttons(1);
        previousSave = any(keys(saveKeys)); previousSpace = any(keys(KbName('space')));
        previousGrow = any(keys(growKeys)); previousShrink = any(keys(shrinkKeys));
        WaitSecs('YieldSecs', 0.01); continue;
    end
    if any(keys(KbName('ESCAPE')))
        fprintf('Calibration aborted without saving.\n'); return;
    end
    rect = Screen('Rect', window); % GUI windows may be resized as well as moved.
    mouseDown = buttons(1);
    if mouseDown && ~previousMouse && all([mx my] >= patch.rect(1:2)) && ...
            all([mx my] < patch.rect(3:4))
        dragging = true; dragOffset = [mx my] - position;
    end
    if ~mouseDown, dragging = false; end
    if dragging, position = round([mx my] - dragOffset); end
    previousMouse = mouseDown;
    space = any(keys(KbName('space')));
    if space && ~previousSpace, white = ~white; end
    previousSpace = space;
    grow = any(keys(growKeys)); shrink = any(keys(shrinkKeys));
    side = min(max(1, side + resizeStep * ...
        (double(grow && ~previousGrow) - double(shrink && ~previousShrink))), min(rect(3:4)));
    previousGrow = grow; previousShrink = shrink;
    delta = [double(any(keys(KbName('RightArrow')))) - double(any(keys(KbName('LeftArrow')))), ...
        double(any(keys(KbName('DownArrow')))) - double(any(keys(KbName('UpArrow'))))];
    if any(delta) && now >= nextMove
        position = position + step * delta;
        nextMove = now + 0.05;
    end
    position = min(max(position, [0 0]), rect(3:4) - side);
    patch.rect = [position position + side]; patch.size_px = [side side];
    Screen('FillRect', window, patch.black);
    color = patch.black; if white, color = patch.white; end
    Screen('FillRect', window, color, patch.rect);
    Screen('Flip', window);
    saveDown = any(keys(saveKeys));
    if saveDown && ~previousSave, break; end
    previousSave = saveDown;
end
% Query the CURRENT client-area origin, including title-bar/window movement.
% rect remains display-local for the existing full-screen acquisition scripts.
windowGlobal = Screen('GlobalRect', window);
patch.calibration_rect = patch.rect;
patch.calibration_window_rect = windowGlobal;
patch.screen_global_rect = screenGlobal;
patch.desktop_rect = patch.rect + repmat(windowGlobal(1:2), 1, 2);
patch.rect = patch.desktop_rect - repmat(screenGlobal(1:2), 1, 2);
assert(all(patch.rect(1:2) >= 0) && all(patch.rect(3:4) <= resolution), ...
    'M1:PatchScreen', 'Keep the patch entirely on selected display %d before saving.', screenNumber);
patch.saved_local = char(datetime('now'));
save(file, 'patch');
fprintf('Saved %d x %d pixel patch to %s\n', side, side, file);
end

function close_calibration(oldShield, oldSync)
m1_cleanup([]);
Screen('Preference', 'WindowShieldingLevel', oldShield);
Screen('Preference', 'SkipSyncTests', oldSync);
end
