function res = ita_playrec(varargin)
% ITA_PLAYREC - 

% <ITA-Toolbox>
% This file is part of the ITA-Toolbox. Some rights reserved.
% You can find the license for this m-file in the license.txt file in the ITA-Toolbox folder.
% </ITA-Toolbox>

persistent result
if isempty(result)
    result = ita_playrec_show_strings(ita_preferences('playrec'));
end
res = result;

% to update handle when preferences are changed
if nargin && strcmp(varargin{1},'updateMexFile')
    result = ita_playrec_show_strings(ita_preferences('playrec'));
    res = result;
    return; %to not trigger playrec calls
end


if nargin 
    result(varargin{:})
end
end