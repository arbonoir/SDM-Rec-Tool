function [] = ita_delete_toolboxpaths(varargin)
% delete all ITA-Toolbox paths in MATLAB

% <ITA-Toolbox>
% This file is part of the ITA-Toolbox. Some rights reserved. 
% You can find the license for this m-file in the license.txt file in the ITA-Toolbox folder. 
% </ITA-Toolbox>


%% remove ita_pathhandling portion in user startup script
ita_startup_content = ita_startup_script_content();
startup_file_user = fullfile(userpath(), 'startup.m');

%% remove existing paths from current matlab paths
if exist('ita_pathToAddOnStartup.m','file')
    pathStr  = ita_pathToAddOnStartup();
    paths2delete = regexp(pathStr,pathsep,'split');

    if ~isempty(paths2delete)
        rmpath(paths2delete{:})
    end
end

%% remove automatic addpath on from startup script
if exist(startup_file_user, 'file')
    % check if a startup file exists and append userpath if necessary
    startup_script_content = splitlines(fileread(startup_file_user));
    if ~isempty(startup_script_content)
        ita_startup_content = splitlines(sprintf(ita_startup_script_content()));
        ita_startup_content_old = splitlines(sprintf(ita_startup_script_content('Version',9)));
    
        %remove ita part
        lines2remove = strcmp(startup_script_content,ita_startup_content{1}) | ...
                       strcmp(startup_script_content,ita_startup_content{2}) | ...
                       strcmp(startup_script_content,ita_startup_content_old{1}) | ...
                       strcmp(startup_script_content,ita_startup_content_old{2});
    
        startup_script_content = join(startup_script_content(~lines2remove),'\n');
    
        % and save
        if isempty(startup_script_content{:})
            delete(startup_file_user);
        else
            fileID = fopen(startup_file_user, 'w');
            fprintf(fileID,"%s\n", startup_script_content{:});
            fclose(fileID);
        end
    end
end

%% delete file containing ita_paths which was called on startup
if exist('ita_pathToAddOnStartup.m','file')
    fileToDelete = which('ita_pathToAddOnStartup.m');
    delete(fileToDelete)
end
