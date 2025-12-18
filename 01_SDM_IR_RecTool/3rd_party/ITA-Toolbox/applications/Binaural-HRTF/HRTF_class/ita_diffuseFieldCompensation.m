function [difusefieldCompensated, comm] = ita_diffuseFieldCompensation(varargin)
%ITA_DIFFUSEFIELDCOMPENSATION - calculate the common component and diffuse
%field compensated version of the input
%  This function calculates the common component using directional weights
%  and subtracts it from all directions returning the diffuse field
%  compensated input
%
%   Input sampling should be equiangular or at least sliceable in theta to
%   work properly. Some tests are implemented to check this, but be aware
%   they might not catch all special cases. If your sampling is a special
%   case, please provide 'weights' as an input option.
%
%  Syntax:
%   hrtfObjOut = ita_diffuseFieldCompensation(audioObjIn, options)
%
%   Options (default):
%           'weights' ('internal') : weight per direction, either as double
%                                   array or string argument ('voronoi'),[x,x,x...]
%           'tol'     (1e-6)
%
%
%  Example:
%   hrtfObjOut = ita_diffuseFieldCompensation(itaHRTFObj,'weights',1)
%
%  See also:
%   ita_toolbox_gui, ita_read, ita_write, ita_generate
%
%   Reference page in Help browser
%        <a href="matlab:doc ita_diffuseFieldCompensation">doc ita_diffuseFieldCompensation</a>

% <ITA-Toolbox>
% This file is part of the ITA-Toolbox. Some rights reserved.
% You can find the license for this m-file in the license.txt file in the ITA-Toolbox folder.
% </ITA-Toolbox>


% Author: Hark Braren -- Email: hark.braren@akustik.rwth-aachen.de
% Created:  06-Dec-2021


%% Initialization and Input Parsing
sArgs        = struct('pos1_data',  'itaAudio',... %(or itaHRTF)
                      'weights',    'internal',...
                      'tol',         1e-6);
[input,sArgs] = ita_parse_arguments(sArgs,varargin);

if isa(input,'itaHRTF')
    % HRTF needs seperate processing of left and right ear
    isHrtf = true;
    ita_verbose_info('Sorting HRTF by Theta and Phi angles',1)
    input  = input.sortByThetaAndPhi;
    
    %assign coordinates to work with
    coords = input.dirCoord;
else
    isHrtf = false;
    %sorting not implemented for itaAudio
    ita_verbose_info('Sorting audioObj by Theta and Phi angles',1)
    [~,sortIdx] = sortrows(input.channelCoordinates.sph,[2,3]);
    input = input.ch(sortIdx);
    
    %assign coordinates to work with
    coords = input.channelCoordinates;
end

%% Calculate Spatial Weights
switch class(sArgs.weights)
    case 'char'
        if strcmpi(sArgs.weights,'internal')
            if isempty(coords.weights)
               ita_verbose_info('coordinatesObj.weights appears to be empty, computing voronoi weights instead')
               sArgs.weights = 'voronoi';
            else
                weights = coords.weights;
            end
        end
        if strcmpi(sArgs.weights,'voronoi')
            weights = calculate_voronoi_weights(coords,sArgs.tol);
%             data.weights = weights; %useless because value object
        else
            ita_verbose_info('unknown argument for ''weights'' provided, please double check');
        end
    case 'double'
        %weights are explicitly provided
        if isscalar(sArgs.weights)
            %single value -> use for all channels
            weights = repmat(sArgs.weights,coords.nPoints,1);
        else
            if numel(sArgs.weights) == data.mChannels
                weights = sArgs.weights;
            else
                error('Number of weights does not match number of channels in input object')
                return;
            end
        end
end


%normalize weights
weights  = weights / sum(weights);

%% calculate common component and diffuse field compensated version of input
if isHrtf
    weightBin = zeros(2*numel(weights),1);
    weightBin(1:2:end) = weights;
    weightBin(2:2:end) = weights;
    
    weightedEnergy = input;
    weightedEnergy.freqData = bsxfun(@times,abs(input.freqData).^2,weightBin');
    
    energySumL = sum(weightedEnergy.freqData(:,weightedEnergy.EarSide=='L'),2);
    energySumR = sum(weightedEnergy.freqData(:,weightedEnergy.EarSide=='R'),2);
    
    %% Common Component
    comm = input;
    comm.freqData(:,1:2:numel(weightBin)) = repmat(sqrt(energySumL),1,numel(weights));
    comm.freqData(:,2:2:numel(weightBin)) = repmat(sqrt(energySumR),1,numel(weights));
    
    % adding minimum phase: could be nicer...
    comm.freqData = comm.freqData.*exp(1j*abs( hilbert(-log(abs(comm.freqData)))));
    comm.TF_type = 'Common';
    
    difusefieldCompensated = ita_divide_spk(input,comm,'regularization',[0 20000]);
    %remove redundant data
    comm = comm.ch(1:2);
else
    weightedEnergy = input;
    weightedEnergy.freqData = bsxfun(@times,abs(input.freqData).^2,weights');
    
    energySum = sum(weightedEnergy.freqData,2);
    
    %% Common part
    comm = input;
    comm.freqData = repmat(sqrt(energySum),1,numel(weights));
    
    % adding minimum phase: could be nicer...
    comm.freqData = comm.freqData.*exp(1j*abs( hilbert(-log(abs(comm.freqData)))));
    comm.userData = {'Common component in diffuse field compensation'};
    
    difusefieldCompensated = ita_divide_spk(input,comm,'regularization',[0 20000]);
    %single channel as output
    comm = comm.ch(1);
end


%end function
end


function weights = calculate_voronoi_weights(data,tol)
% calculate weights according to area represented by each sampled direcion
%

%% typical Case -> spherical data
if any(data.r ~= data.n(1).r)
    ita_verbose_info('Non-spherical data detected, radius varies between sample positions',0)
end

thetaU = unique(data.theta);
meanAngleDelta_theta = mean(diff(sort(thetaU)));
stdAngleDelta_theta  = std(diff(sort(thetaU)));

%rough criterion to see if lower cap is missing
lowerCapMissing = (pi-max(data.theta)) > meanAngleDelta_theta+2*stdAngleDelta_theta;
upperCapMissing = min(data.theta) > meanAngleDelta_theta+2*stdAngleDelta_theta;

if lowerCapMissing || upperCapMissing
    ita_verbose_info('Missing cap detected in spherical coordinates - modifying weights at boundary to cap',1);
    weights = handleMissingSphericalCap(data,lowerCapMissing,upperCapMissing,meanAngleDelta_theta,tol);
else
    [~, weights] = spherical_voronoi(data);
end


end %funciton: calculate_voronoi_weights


function weights = handleMissingSphericalCap(coords,lowerCapMissing,upperCapMissing,deltaTheta,tol)
% if a cap is missing, add another ring of points on the same equiangular
% sampling as the data and calculate weights for this sampling, the remove
% the weights for the added points
dataTemp = coords;

newDataIdx = [];

if upperCapMissing
    %add another ring on top (beginning of position list)
    %find theta angle
    thetaMin = min(coords.theta);
    newTheta = thetaMin-deltaTheta;
    if newTheta < 0 %pole might be missing, sampling as close as possible, no need to correct 
        ita_verbose_info('No missing Cap detected, maybe just a missing pole?',2)
    else
        %add another ring
        phiAngles = coords.phi(abs(coords.theta-thetaMin)<tol);
        radius = coords.r(abs(coords.theta-thetaMin)<tol);
        newRing = itaCoordinates(numel(azimuthAngles));
        newRing = newRing.makeSph;
        newRing.r = radius;
        newRing.theta = newTheta;
        newRing.phi = phiAngles;
        % add to temp Coordinates
        dataTemp = [newRing,dataTemp];
        
        newDataIdx = [newDataIdx,1:newRing.nPoints];
    end
end

if lowerCapMissing
    %add another ring on top (bottom of position list)
    %find theta angle
    thetaMax = max(coords.theta);
    newTheta = thetaMax+deltaTheta;
    if newTheta > pi %pole might be missing, sampling as close as possible, no need to correct 
        ita_verbose_info('No missing Cap detected, maybe just a missing pole?',2)
    else
        
        phiAngles = coords.phi(abs(coords.theta-thetaMax)<tol);
        radius = coords.r(abs(coords.theta-thetaMax)<tol);
        newRing = itaCoordinates(numel(azimuthAngles));
        newRing = newRing.makeSph;
        newRing.r = radius;
        newRing.theta = newTheta;
        newRing.phi = phiAngles;
        
        % add to temp Coordinates
        newDataIdx = [newDataIdx,dataTemp.nPoints+1:(dataTemp.nPoints+newRing.nPoints)];
        dataTemp = [dataTemp,newRing];
        
       
    end
end

[~, weights] = spherical_voronoi(dataTemp);
idx = 1:numel(weights);
idxKeep = setdiff(idx,newDataIdx);
%only keep the ones for the original Coordinates
weights = weights(idxKeep);
end
%eof
