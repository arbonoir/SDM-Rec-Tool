function [centerPoint,returnData] = ita_HRTFarc_pp_itdInterpolate(dataIn,coordsIn,options,plotFitting)
% calculate the zero crossing of the ITD in the horizontal plane from the
% input data and return the phi-angle offset and the optimized data
%
% Usage:
%   [centerPoint,dataOptimized] = ita_HRTFarc_pp_itdInterpolate(dataIn,coordsIn,options)
%
%   Arguments:
%       dataIn: either a 1x2 itaAudio or an itaHRTF object
%       coordsIn: coordinates for each measurement
%                 if not set, channelCoordinates of the first itaAudio or
%                 dirCoords of the input HRTF are taken
%       options:
%           options.itdMethod: ('xcorr') see itaHRTF.ITD
%           options.dataChannels (1:2) provide if not all channels have
%                                      useable data
%           options.resolution (0.1) resolution of compensation in deg,
%                                    must be > 0.1
%
%   [centerPoint,hrtfOptimized] = ita_HRTFarc_pp_itdInterpolate(hrtf)

    if nargin < 4
        plotFitting = false;
    end

    if nargin < 3 || isempty(options)
        options.itdMethod = 'xcorr';
        options.dataChannel = 1:2;
        options.resolution = 0.1; %resolution of correction in deg
    end

    if nargin < 2 
        if isa(dataIn,'itaHRTF')
            %             channelCoordinates = dataIn.dirCoords; % not needed
        else %itaAudio
            coordsIn = dataIn(1).channelCoordinates;
        end
    end

    if ~isa(dataIn,'itaHRTF')
        % if itaAudio -> turn into hrtf
        channel1 = 1;
        channel2 = ceil(length(options.dataChannel)/2+1);

        dataIn(channel1).channelCoordinates = coordsIn;
        dataIn(channel2).channelCoordinates = coordsIn;
        tmp(1) = dataIn(channel1);
        tmp(2) = dataIn(channel2);
        hrtf = itaHRTF(tmp.merge);
    else
        hrtf = dataIn;
    end

    % get horizontal plane
     if ~isfield(options,'exactSearchSlice')
        options.exactSearchSlice = 1;                                   % only allow one exact elevation in slice
     end

     slice = hrtf.sphericalSlice('theta_deg',90,options.exactSearchSlice);

    % make sure coords are identical for L and R (sdo: should be unnecessary but for some reason, sometimes not)
    slice.channelCoordinates.phi_deg(2:2:slice.nChannels) = slice.channelCoordinates.phi_deg(1:2:slice.nChannels);
    
    % detect non-unique phi angles and reduce to unique direction (added 11.11.2021 - sdo)
    [~,idxDim] =  uniquetol(slice.channelCoordinates.phi_deg);
    idxDimUnsorted = (sort(idxDim)+[0,1]).'; % eliminated = setdiff(1:2:slice.nChannels,idxDim)
    slice = slice.ch(idxDimUnsorted(:));
    
    % set elevation to a single height - necessary when applying elevation correction in post-processing
    slice.channelCoordinates.theta_deg = slice.channelCoordinates.theta_deg(1);
    
    if strcmp(options.itdMethod,'xcorr')
        data = slice.ITD('method','xcorr','filter',[400 1500]);%[400 2000]);
    else
        data = slice.ITD('method','phase_delay','filter',[1100 2000]);
    end
    xData = slice.getEar('L').channelCoordinates.phi_deg;
    xData = xData.';
    returnData.xData = xData;
    returnData.data = data;
    
    % flip the data if the positions are reversed
    if sum(diff(xData) < 0) > length(xData) / 4
        xData = fliplr(xData);
        data = fliplr(data);
    end



    % repeat 3 times to have a 360 to 0 jump even if the data is correctly
    % aligned 
    xData = repmat(xData,1,3);
    xData = unwrap(xData/180*pi)*180/pi;
    data = repmat(data,1,3);
    
    %% zero point
    % get the zero crossing from negative to positive
    [~,index] = max(diff(sign(data(3:end))));
    
    index = index+2;
    % interpolate between near values
    tmp = data(index-2:index+2);
    xDataSlice = xData(index-2:index+2);

    [polynomials] = polyfit(xDataSlice,tmp,1);
    
    maxXValues = min(xDataSlice):0.1:max(xDataSlice);
    interpData = polyval(polynomials,maxXValues);
    % get the zero crossing 
    [~,maxIndex] = max(abs(diff(sign(interpData))));
      
    centerPoint = mod(maxXValues(maxIndex),360); % frontal zero crossing
    disp(['=== Preliminary (frontal) center point: ', num2str(centerPoint),'° ==='])

    if isfield(options,'itdCorrectionFrontOnly') && options.itdCorrectionFrontOnly == 0
    
        % repeat for crossing from positive to negative
    
        [~,index2] = max(-diff(sign(data(3:end))));

        index2 = index2+2;
        % interpolate between near values
        tmp2 = data(index2-2:index2+2);
        xDataSlice2 = xData(index2-2:index2+2);


        [polynomials2] = polyfit(xDataSlice2,tmp2,1);

        maxXValues2 = min(xDataSlice2):0.1:max(xDataSlice2);
        interpData2 = polyval(polynomials2,maxXValues2);
        % get the zero crossing 
        [~,maxIndex2] = max(abs(diff(sign(interpData2))));

        centerPoint2 = mod(maxXValues2(maxIndex2),360); % rear zero crossing
        
        % combine front and back information
        centerPoint1_rot = mod(centerPoint+180,360); % bring frontal crossing to back
        centerPoint = mod(mean([centerPoint2,centerPoint1_rot])+180,360); % calc. average and return to front
    
    end
    

%% check if the found itd represents a sine
% taken from https://de.mathworks.com/matlabcentral/answers/121579-curve-fitting-to-a-sinusoidal-function
    y = returnData.data;
    x = returnData.xData;
    yMax = max(y);
    yMin = min(y);
    yRange = (yMax-yMin);                               % Range of ‘y’
    yz = y-yMax+(yRange/2);
    xZeroCrossing = x(yz .* circshift(yz,[0 1]) <= 0);     % Find zero-crossings
    period = 2*mean(diff(xZeroCrossing));                     % Estimate period
    ym = mean(y);                               % Estimate offset

    fit = @(b,x)  b(1).*(sin(2*pi*x./b(2) + 2*pi/b(3))) + b(4);    % Function to fit
    fcn = @(b) sum((fit(b,x) - y).^2);                              % Least-Squares cost function
    s = fminsearch(fcn, [yRange;  period;  -1;  ym]);

    if plotFitting
        xp = linspace(min(x),max(x));

        figure(1)
        plot(x,y,'b')
        hold on
        plot(x,fit(s,x), 'r')
    end
    coeffs = corrcoef(y,fit(s,x));
    returnData.error = 1-coeffs(2,1);
end