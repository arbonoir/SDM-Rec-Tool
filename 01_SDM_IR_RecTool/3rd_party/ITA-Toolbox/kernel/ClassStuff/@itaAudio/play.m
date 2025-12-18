function play(this,varargin)
%just play time signal with soundcard

% <ITA-Toolbox>
% This file is part of the ITA-Toolbox. Some rights reserved. 
% You can find the license for this m-file in the license.txt file in the ITA-Toolbox folder. 
% </ITA-Toolbox>

sArgs.matlabAudio = false; %play using matlab functions (no portaudio, non-blocking)
sArgs = ita_parse_arguments(sArgs,varargin);

if this.nChannels == 0
   disp('No data for playback'); 
   return;
end

if exist('ita_portaudio.m','file') && ~sArgs.matlabAudio
    ita_portaudio(this,varargin{:}); 
else
    %fallback solution, can be enforces through audioObj.play('matlabAudio',true)
    sound(this.time, this.samplingRate);
end