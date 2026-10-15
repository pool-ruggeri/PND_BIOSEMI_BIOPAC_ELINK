% Position a measured 4 x 4 cm patch; no serial connection is needed.
% Enter measured ACTIVE screen dimensions (not bezel dimensions) below, or
% leave NaN to enter them in the MATLAB console before the window opens.
screenNumber = max(Screen('Screens'));
screenWidthCm = NaN;
screenHeightCm = NaN;
patchSizeCm = 4;
moveStepPx = 5;
calibrate_patch(fileparts(mfilename('fullpath')), screenNumber, ...
    screenWidthCm, screenHeightCm, patchSizeCm, moveStepPx);

function calibrate_patch(root, screenNumber, widthCm, heightCm, sizeCm, step)
if isnan(widthCm), widthCm = input('Measured active screen width (cm): '); end
if isnan(heightCm), heightCm = input('Measured active screen height (cm): '); end
assert(isscalar(widthCm) && isfinite(widthCm) && widthCm > sizeCm && ...
    isscalar(heightCm) && isfinite(heightCm) && heightCm > sizeCm, ...
    'M1:Dimensions', 'Enter valid measured screen dimensions in cm.');
cleanup = onCleanup(@() m1_cleanup([]));
[window, rect] = m1_display(screenNumber, []);
patch = struct('version', 1, 'screen', screenNumber, 'resolution', rect(3:4), ...
    'screen_cm', [widthCm heightCm], 'size_cm', [sizeCm sizeCm], ...
    'black', [0 0 0], 'white', [255 255 255], 'rect', [], 'saved_local', '');
sizePx = max(1, round([sizeCm / widthCm sizeCm / heightCm] .* rect(3:4)));
position = min([20 20], rect(3:4) - sizePx);
file = fullfile(root, 'opto_patch.mat');
if isfile(file)
    old = load(file, 'patch');
    if isfield(old, 'patch') && old.patch.screen == screenNumber && ...
            isequal(old.patch.resolution, patch.resolution)
        position = old.patch.rect(1:2);
    end
end
patch.rect = [position position + sizePx];
white = true; previousSpace = false; nextMove = 0;
fprintf('Arrows: move; SPACE: black/white; ESC: save position and exit.\n');
fprintf('Use the BBTK app to adjust sensitivity; this script does not set it.\n');
while true
    [~, now, keys] = KbCheck;
    if keys(KbName('ESCAPE')), break; end
    space = keys(KbName('space'));
    if space && ~previousSpace, white = ~white; end
    previousSpace = space;
    if now >= nextMove
        delta = [keys(KbName('RightArrow')) - keys(KbName('LeftArrow')), ...
            keys(KbName('DownArrow')) - keys(KbName('UpArrow'))];
        position = min(max(position + step * double(delta), [0 0]), rect(3:4) - sizePx);
        nextMove = now + 0.05;
    end
    patch.rect = [position position + sizePx];
    Screen('FillRect', window, patch.black);
    if white, Screen('FillRect', window, patch.white, patch.rect); end
    Screen('Flip', window);
end
patch.saved_local = char(datetime('now'));
save(file, 'patch');
fprintf('Saved %d x %d pixel patch to %s\n', sizePx(1), sizePx(2), file);
end
