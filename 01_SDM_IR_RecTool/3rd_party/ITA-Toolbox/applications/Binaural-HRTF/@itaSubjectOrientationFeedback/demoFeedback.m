%DEMOFEEDBACK contains tutorial sections for live or simulated
%subjectOrientationFeedback. This script is not intended to RUN. Rather, 
%use RUN AND ADVANCE or RUN SECTION to proceed through the sections, which 
%are as follows:
%   0. Presets
%   1. Calibrate feedback
%   2. Start feedback
%   3. Stop feedback
%   4. Your code
%
% REMARKS:
% Don't forget to properly setup Motive.
%   Head      - Rigid Body 1
%   Left ear  - Rigid Body 2
%   Right ear - Rigid Body 3
%   (Arc      - Rigid Body 4)
% Please refer to OptiTrack at verdi.akustik.rwth-aachen.de for more
% information.
%
% Author:  Chalotorn Möhlmann
% Date:    2021-06-08
% Release: MATLAB 2019b


% %% TROUBLESHOOTING
% close all;
% clear;
% matlabrc; % system administrator-defined start up script for MATLAB

%% 0. Presets
% If you don't like the presets, you can customize your own.

% true  <--> live measurement (default)
% false <--> simulation
liveFeedback = false;

% 1 <--> GUI1: crosshair
% 2 <--> GUI2: blacksphere (default)
guiVersion = 2;

%% 1. Calibrate feedback (only for live)
if liveFeedback
    subjID = 1;                                 % choose subject ID
    countDown = 25;                             % length of countdown
    
    filePath = matlab.desktop.editor.getActiveFilename;
    folderPath = strrep(filePath,'\conductFeedback.m','');
    folderName = sprintf('ID_%02i',subjID);
    savePath = fullfile(folderPath,folderName); % folder for subject
    if ~exist(savePath, 'dir')                  % If not already existent...
        mkdir(savePath);                        % make folder for subject.
    end
    addpath(savePath);                          % add folder to MATLAB path
    
    iTrack = itaOptitrack('autoconnect', true);
    currentTime = clock();
    timeStampCalib = sprintf('_%4i%02i%02i_%02i_%02i', currentTime(1), ...
        currentTime(2), currentTime(3), currentTime(4), currentTime(5));
    nameCalib = ['calib_', folderName, timeStampCalib];
    iTrack.calibrate('countdownDuration', countDown, ...
        'useCalibration', false, ...
        'savePathCalibration', savePath,...
        'saveNameCalibration', nameCalib);
end
%% 2. Start feedback
if liveFeedback
    obj = itaSubjectOrientationFeedback(iTrack);
    
    obj.version = guiVersion;
    obj.startFeedback();
    
else
    % Find local recording for simulation
    filePath = matlab.desktop.editor.getActiveFilename;
    folderPath = strrep(filePath,'\conductFeedback.m','');
    trackFile = fullfile(folderPath,'\simulationExamples\trackStop_ID_11_20200604_14_08.mat');
    calibFile = fullfile(folderPath,'\simulationExamples\calib_ID_11_20200604_14_06.mat');
    
    obj = load(trackFile);        % of class itaSubjectOrientationFeedback, otherwise re-install toolbox branch
    sub = obj.obj;
    sub.calibFile = calibFile;
    sub.doSimulation = true;
    
    sub.version = guiVersion;
    sub.startFeedback();
    
end

%% 3. Stop feedback
if liveFeedback
    obj.stopFeedback();
else
    sub.stopFeedback();
end

%% 4. Your code
% Have fun!