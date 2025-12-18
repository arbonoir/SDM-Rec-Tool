function measurementChain = ita_measurement_chain_icp_rack(varargin)
%   ITA_MEASUREMENT_CHAIN_ICP_RACK() returns a 32 channel measurementChain Object
%   witch default calibration values for the AD and the ICP preamps
%
%   Options: (default)
%       gain     (0)   0/20/40 - default gain set for all 24 channels, or per
%                             ICP channel if vector is supplied
%       chOffset (64)   number of channels before ch1 of RME 32 Pro ad
%                       (typically used with Octamic rack where first 64
%                        channels are the first optical madi stream)
%       'canCalibrate' (true) : if false, the calibration of the values set
%                               in this function are skipped when calling
%                               measurementChain.calibrate
%  Syntax: measurementChain = ita_measurement_chain_icp_rack()
%          measurementChain = ita_measurement_chain_icp_rack('gain',20,'chOffset',0,'canCalibrate',false)

% <ITA-Toolbox>
% This file is part of the ITA-Toolbox. Some rights reserved.
% You can find the license for this m-file in the license.txt file in the ITA-Toolbox folder.
% </ITA-Toolbox>


% Author: Hark Braren -- Email: hark.braren@akustik.rwth-aachen.de
% Created:  05-Feb-2024


%% parse arguments
sArgs.gain = 0;
sArgs.chOffset = 64;
sArgs.canCalibrate = true;

sArgs = ita_parse_arguments(sArgs,varargin);

%% Default Calibration Values
%      CH:        1         2         3         4         5         6        7         8         9        10        11        12        13        14        15        16        17        18        19        20        21        22        23        24        25        26        27        28        29        30        31        32
rmeCal =  [  0.0594    0.0596    0.0595    0.0595    0.0594    0.0595    0.0595    0.0595    0.0595    0.0596    0.0596    0.0595    0.0594    0.0595    0.0595    0.0596    0.0595    0.0596    0.0595    0.0595    0.0594    0.0596    0.0595    0.0594    0.0594    0.0595    0.0596    0.0595    0.0595    0.0594    0.0594    0.0594];
ICP0dB =  [  1.0031    1.0032    1.0031    1.0016    1.0029    1.0124    1.0021    1.0031    1.0039    1.0040    1.0052    1.0015    1.0048    1.0026    1.0023    1.0032    1.0025    1.0041    1.0022    1.0023    1.0066    1.0036    1.0059    1.0045];
ICP20dB = [ 10.0411   10.0558   10.0579   10.0524   10.0539   10.1338   10.0824   10.0696   10.0311   10.0595   10.0618   10.0225   10.0718   10.0428   10.0289   10.0222   10.0338   10.0479   10.0352   10.0204   10.0776   10.0584   10.0731   10.0679];
ICP40dB = [100.3424  100.1040  100.3898   99.8823   99.3611  100.3893   99.7895   99.8413   99.6282  100.2005  100.6122   99.1552  100.6083   99.9167  100.1663   99.5030   99.2878   99.2427   99.9557   99.6164  100.7594   99.3040   99.8216  100.1462];


%% create object
measurementChain = itaMeasurementChain();

for iCh = 1:32
    %channel
    measurementChain(iCh).hardware_channel = iCh+sArgs.chOffset;

    %AD
    measurementChain(iCh).elements(1) = itaMeasurementChainElements('ad');
    measurementChain(iCh).elements(1).name = sprintf('RME M-32 Pro AD hwch %02d',iCh);
    measurementChain(iCh).elements(1).sensitivity = itaValue(rmeCal(iCh),'1/V');

    if sArgs.canCalibrate == false
        measurementChain(iCh).elements(1).calibrated = -1;
    end
    
    %ICP
    if iCh < 24
        measurementChain(iCh).elements(2) = itaMeasurementChainElements('preamp');
        measurementChain(iCh).elements(2).name = sprintf('ICP Rack Unit%d iCh%d',ceil(iCh/8),rem(iCh-1,8)+1);
        switch sArgs.gain %HBR: ToDo - add per channel gain gain setting
            case 0
                measurementChain(iCh).elements(2).sensitivity = ICP0dB(iCh);
            case 20
                measurementChain(iCh).elements(2).sensitivity = ICP20dB(iCh);
            case 40
                measurementChain(iCh).elements(2).sensitivity = ICP40dB(iCh);
            otherwise
                error('Wrong ''gain'' parameter, try 0, 20, or 40');
        end

        if sArgs.canCalibrate == false
            measurementChain(iCh).elements(2).calibrated = -1;
        end
    end
end