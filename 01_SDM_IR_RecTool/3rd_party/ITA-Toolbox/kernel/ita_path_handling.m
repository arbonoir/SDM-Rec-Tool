function varargout = ita_path_handling(varargin)
% handle the ITA-toolbox paths in MATLAB
%
% This function is not supposed to get triggered directly
% ita_generate_documentation needs a pathList not pathStr
%
% CALL: ita_path_handling
%       pathStr = ita_path_handling
%       [pathStr pathList] = ita_path_handling
%

% <ITA-Toolbox>
% This file is part of the ITA-Toolbox. Some rights reserved.
% You can find the license for this m-file in the license.txt file in the ITA-Toolbox folder.
% </ITA-Toolbox>

%% Settings
if nargin > 0
    error('There should not be any input arguments to ita_path_handling');
end
ignoreList  = {'.git','.svn','private','tmp','prop-base','props','text-base','template','doc','helpers'};

%% toolbox prefix string
toolboxPath = ita_toolbox_path();
fullPathParts = regexp(toolboxPath,filesep,'split');
prefixToolbox = fullPathParts{end};
pathStr = genpath(toolboxPath);
addpath(toolboxPath)

%% path handling
outpathList    = regexp(pathStr,pathsep,'split');
outpathList    = outpathList(~cellfun(@isempty,outpathList)); % kick out empty entries

% kick out ignore entries
for idx=1:numel(ignoreList)
    ignoreEntries = cellfun(@strfind,outpathList,repmat(ignoreList(idx),1,numel(outpathList)),'UniformOutput',false);
    validIdx = cellfun(@isempty,ignoreEntries);
    outpathList = outpathList(validIdx);
end

% remove old toolbox paths first then add new ones to
if ~isempty(outpathList)
    ita_delete_toolboxpaths;
    warnstate = warning('off','MATLAB:dispatcher:pathWarning'); %RSC: quiet
    addpath(outpathList{:})
    warning(warnstate);
end

%% Save the path list if possible
ita_verbose_info('ita_path_handling::Saving path list to ita_pathsToAddOnStartup.m in local userpath...',1);
upath = userpath();
if isempty(upath)
    userpath('reset');
end

if isempty(userpath())
    ita_verbose_info('Oh Lord! I cannot set your userpath. Please check if the default directory exists or manually try saving your path variable.', 0);
else
    %% check if depricated pathdef file containing ita content is still in userpath
    if exist(fullfile(upath,'pathdef.m'),'file')
        ita_verbose_info(sprintf('Found pathdef.m in your userpath (%s), which may have come from an old ITA-Toolbox install',fullfile(upath,'pathdef.m')),0);
        ita_switch_to_new_path_handling();
    end
    %% add automated addpath at startup
    
    % fileID = fopen(fullfile(upath,'ita_pathsToAddOnStartup.m'), 'w');
    % fprintf(fileID, 'function p = ita_pathsToAddOnStartup()\n');
    % fprintf(fileID,'p = [... \n');
    % fprintf(fileID,'%%%% ITA PATH ENTRIES %%%%\n');
    % fprintf(fileID,['''%s',pathsep,''' , ...\n'],outpathList{:});
    % fprintf(fileID,'];');
    % fclose(fileID);

    ita_savepath(outpathList,'replace')

end


%% Create a custom startup file to set the correct path at startup
ita_verbose_info('ita_path_handling::Updating startup.m in local userpath...',1);

ita_startup_script = ita_startup_script_content();
startup_file_in_userpath = fullfile(upath, 'startup.m');

if exist(startup_file_in_userpath, 'file')
    % check if a startup file exists and append userpath if necessary
    existing_startup_script = fileread(startup_file_in_userpath);
    if ~contains(existing_startup_script, ita_startup_script)
        %this should always be the case (ita_delete_toolbox_path was called)
        if isempty(existing_startup_script)
            %empty -> fill with ita content
            final_startup_script = ita_startup_script;
        else
            %not empty -> append ita content after newline
            final_startup_script = strcat(existing_startup_script,'\n',ita_startup_script);
        end
    else
        %something went wrong if we get here or someone changed the
        %remove old toolbox paths first after line 40
        error('How did we get here??')
    end
else
    % startup.m does not exist -> create one with ita content
    final_startup_script = ita_startup_script;
end

%write content to startup.m file
fileID = fopen(startup_file_in_userpath, 'w');
fprintf(fileID, final_startup_script);
fclose(fileID);


%% Return path
if nargout
    outpathStr = [];
    prefixToolboxIdx = strfind(toolboxPath,prefixToolbox);
    for idx = 1:numel(outpathList)
        outpathStr = [outpathStr pathsep outpathList{idx}]; %#ok<AGROW>
        outpathList{idx} = outpathList{idx}(prefixToolboxIdx:end);
    end

    varargout{1}=outpathStr(2:end);
    if nargout == 2
        varargout{2}=outpathList;
    end
end
end


function ita_switch_to_new_path_handling()

    %% ask to delete pathdef.m
    pathdef_user_file = fullfile(userpath(),'pathdef.m');
    questionStr = sprintf('The ITA-Toolbox is no longer utelizing the pathdef.m file in the user directory.\n Do you want us to delete %s automatically.\nYou may have to manually add custom paths to matlab path after the next startup.',pathdef_user_file);
    res = questdlg(questionStr,'ita_toolbox: Updating path handling.','Delete','Keep','Delete');
    
    switch res
        case 'Delete'
            if exist(pathdef_user_file,'file')
                delete(pathdef_user_file);
            end
        case {'Keep'}
            ita_verbose_info(sprintf('ita_toolbox_setup is removing the ''addpath(pathdef())'' from %s',pathdef_user_file),0)
            ita_verbose_info('Please handle the further use of it manually.',0)
    end

end