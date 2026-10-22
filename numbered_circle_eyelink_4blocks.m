% M5: four blocks, fresh calibration AND validation and B1 SYNC per block.
% Set the tPAD virtual COM port from Windows Device Manager.
comPort = 'COM5';
m3_run_circles(fileparts(mfilename('fullpath')), comPort, 4);
