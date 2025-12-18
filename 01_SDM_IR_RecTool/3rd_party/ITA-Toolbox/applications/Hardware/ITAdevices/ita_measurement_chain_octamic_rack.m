function measurementChain = ita_measurement_chain_octamic_rack(varargin)
%ITA_MEASUREMENT_CHAIN_OCTAMIC_RACK - returns measurement Chain with default
% values for octamic measurement rack. Typically matching within 0.05 dB
%
%  Syntax:
%   measurementChain = ita_measurement_chain_octamic_rack(options)
%
%   Options (default):
%           'gain' (0) : gain set for the channel on the octamic in dB
%           'canCalibrate' (true) : if false, the calibration of the octamic
%           sensitivities are skipped when calling measurementChain.calibrate
%           'defaultSensor' ([]) : itaMeasurementChainElements('sensor')
%           sets the given default sensor on each channel, see example
%           (the sensor will still be calibratable)
%
%
%  Example simple:
%   msc = ita_measurement_chain_octamic_rack(options)
%
% Example using KE4 mics and wanting a quick setup:
%   sensorKE4 = itaMeasurementChainElements('sensor');
%   sensorKE4.name = 'Sennheiser KE4-%02d'; % %02d will be replaced with the channelNumber during setup, if you leave it out all sensors will have the same name
%   sensorKE4.sensitivity = itaValue(10e-3,'V/Pa') %approximate average value - should ba calibrated!!!!
%   msc = ita_measurement_chain_octamic_rack('canCalibrate',false,'defaultSensor',sensorKE4)
%
% set Measurement chain in measurement object.
%   ms = itaMSTF;
%   ms.inputMeasurementChain = msc;
%   ms.inputChannels = [1,15,24]; % no need to use all, once selected only the three channels will appear in ms.calibrate
%
% if you want to use the GUI for the output chain you can do so:
%   ms.outputMeasurementChain = ita_measurement_chain_output();      
%   
%  See also:
%   ita_measurement_chain, ita_measurement_chain_icp_rack, itaMeasurementChainElements 
%
%   Reference page in Help browser
%        <a href="matlab:doc octamicRack0dBMeasurementChain">doc octamicRack0dBMeasurementChain</a>

% <ITA-Toolbox>
% This file is part of the ITA-Toolbox. Some rights reserved.
% You can find the license for this m-file in the license.txt file in the ITA-Toolbox folder.
% </ITA-Toolbox>


% Author: Hark Braren -- Email: hark.braren@akustik.rwth-aachen.de
% Created:  27-Jun-2023


%% Initialization and Input Parsing
sArgs.gain = 0;
sArgs.canCalibrate = true;
sArgs.defaultSensor = [];
sArgs = ita_parse_arguments(sArgs,varargin);

if ~isempty(sArgs.defaultSensor) && ~strcmp(sArgs.defaultSensor.type,'sensor')
    ita_verbose_info('Wrong defaultSensor type. Please provide a itaMeasurementChainElements(''sensor''). Ignoring defaultSensor argument.')
    sArgs.defaultSensor = [];
end

%% Default calibration Values
%calibrated on 27-Jun-23 with 0 dB gain at 1 V
%              1         2         3         4         5         6         7         8         9        10         11        12        13        14        15        16        17        18        19        20        21        22        23        24        25        26        27        28        29        30        31        32
octamicCal =  [0.2299    0.2300    0.2288    0.2296    0.2290    0.2296    0.2304    0.2307    0.2269    0.2270    0.2266    0.2269    0.2271    0.2265    0.2274    0.2263    0.2286    0.2272    0.2275    0.2273    0.2284    0.2287    0.2292    0.2256    0.2274    0.2279    0.2297    0.2290    0.2297    0.2301    0.2293    0.2289];


%% Set up measurement Chain
measurementChain = itaMeasurementChain();
for iCh = 1:32
    %channel
    measurementChain(iCh).hardware_channel = iCh;
    %AD
    measurementChain(iCh).elements(1) = itaMeasurementChainElements('ad');
    measurementChain(iCh).elements(1).name = sprintf('Octamic XTC hwch%02d (Nr.%d iCh%d)',iCh,ceil(iCh/8),rem(iCh-1,8)+1);
    channelSensitivity = octamicCal(iCh)*10^(sArgs.gain/20);
    measurementChain(iCh).elements(1).sensitivity = itaValue(channelSensitivity,'1/V');

    if sArgs.canCalibrate == false
        measurementChain(iCh).elements(1).calibrated = -1;
    end

    %Sensor
    if ~isempty(sArgs.defaultSensor)
        measurementChain(iCh).elements(2) = sArgs.defaultSensor
        if contains(sArgs.defaultSensor.name,'%')
            measurementChain(iCh).elements(2).name = sprintf(measurementChain(iCh).elements(2).name,iCh);
        end
    end
end %for loop

%end function
end