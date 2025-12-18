function str_startup_script = ita_startup_script_content(varargin)
%ITA_STARTUP_SCRIPT_CONTENT - returm the text added to the user startup.m
%  This function returns the text which the toolbox installer adds to the
%  users startup.m in order to automatically add the toolbox path on
%  startup
%
%  Syntax:
%       str_startup_script = ita_startup_script_content()
%
%  See also:
%   ita_toolbox_setup, ita_path_handling, ita_delete_toolboxpath
%
%   Reference page in Help browser 
%        <a href="matlab:doc ita_startup_script_content">doc ita_startup_script_content</a>

% <ITA-Toolbox>
% This file is part of the ITA-Toolbox. Some rights reserved. 
% You can find the license for this m-file in the license.txt file in the ITA-Toolbox folder. 
% </ITA-Toolbox>


% Author:  Hark Braren -- Email: hark.braren@akustik.rwth-aachen.de
% Created:  22-Mar-2023 

sArgs.version = ita_toolbox_version_number();
sArgs = ita_parse_arguments(sArgs,varargin);

if sArgs.version<=9
    %return old startup script - needed to smooth the switch to new path
    %handling behaviour
    str_to_startup = 'addpath(pathdef())';
    str_startup_script = strcat('disp(''Loading ita_toolbox_path from local pathdef.'')\n', str_to_startup);
else
    %return current version
    str_to_startup = 'addpath(ita_pathsToAddOnStartup())';
    str_startup_script = strcat('disp(''Loading ita_toolbox_path from userpath.'')\n', str_to_startup);
end


%end function
end
