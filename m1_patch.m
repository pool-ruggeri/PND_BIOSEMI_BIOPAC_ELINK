function patch = m1_patch(root)
%M1_PATCH Load the one calibration shared by the acquisition scripts.
file = fullfile(root, 'opto_patch.mat');
assert(isfile(file), 'M1:Calibration', 'Run opto_calibration first: %s', file);
saved = load(file, 'patch');
assert(isfield(saved, 'patch'), 'M1:Calibration', 'Invalid patch file.');
patch = saved.patch;
assert(patch.version == 1 && isequal(patch.black, [0 0 0]) && ...
    isequal(patch.white, [255 255 255]), 'M1:Calibration', ...
    'Incompatible patch colors/configuration. Repeat opto_calibration.');
end
