% Position and resize an optical patch in pixels; no serial connection needed.
screenNumber = max(Screen('Screens'));
initialSizePx = 150;
moveStepPx = 5;
resizeStepPx = 10;
calibrate_patch(fileparts(mfilename('fullpath')), screenNumber, ...
    initialSizePx, moveStepPx, resizeStepPx);

function calibrate_patch(root, screenNumber, initialSize, step, resizeStep)
cleanup = onCleanup(@() m1_cleanup([]));
[window, rect] = m1_display(screenNumber, []);
ShowCursor('Arrow', window);
patch = struct('version', 1, 'screen', screenNumber, 'resolution', rect(3:4), ...
    'black', [0 0 0], 'white', [255 255 255], 'rect', [], ...
    'size_px', [], 'saved_local', '');
side = min(initialSize, min(rect(3:4)));
position = min([20 20], rect(3:4) - side);
file = fullfile(root, 'opto_patch.mat');
if isfile(file)
    old = load(file, 'patch');
    if isfield(old, 'patch') && old.patch.screen == screenNumber && ...
            isequal(old.patch.resolution, patch.resolution) && ...
            numel(old.patch.rect) == 4 && all(isfinite(old.patch.rect)) && ...
            all(old.patch.rect(3:4) > old.patch.rect(1:2))
        side = min(max(1, round(max(old.patch.rect(3:4) - old.patch.rect(1:2)))), min(rect(3:4)));
        position = old.patch.rect(1:2);
    end
end
position = min(max(round(position), [0 0]), rect(3:4) - side);
patch.rect = [position position + side]; patch.size_px = [side side];
keyNames = KbName('KeyNames');
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
    if any(keys(KbName('ESCAPE')))
        fprintf('Calibration aborted without saving.\n'); return;
    end
    [mx, my, buttons] = GetMouse(window);
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
patch.saved_local = char(datetime('now'));
save(file, 'patch');
fprintf('Saved %d x %d pixel patch to %s\n', side, side, file);
end
