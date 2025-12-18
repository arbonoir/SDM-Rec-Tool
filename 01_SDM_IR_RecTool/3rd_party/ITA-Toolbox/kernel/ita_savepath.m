function ita_savepath(pathIn,mode)
%ITA_SAVEPATH - Save ita_paths so they are automatically added on startup
%  This function writes provided paths in ita_pathToAddOnStartup in the
%  MATLAB User folder, so it is added to the Matlab path on startup
%
%  Call: ita_savepath(pathIn,'append') (default)
%        ita_savepath(pathIn,'replace')
%
%   pathIn can be a char array seperated by pathsep() (like provided by genpath) 
%   pathIn be a 1xN cell array, each cell containing a seperate path to
%   add

%   Reference page in Help browser
%      <a href="matlab:doc ita_toolbox_setup">doc ita_toolbox_setup</a>
%
% Autor: Hark Braren -- Email: hark.braren@akustik.rwth-aachen.de
% Created:  08.12.2023

% <ITA-Toolbox>
% This file is part of the ITA-Toolbox. Some rights reserved.
% You can find the license for this m-file in the license.txt file in the ITA-Toolbox folder.
% </ITA-Toolbox>


%%
if nargin < 2
    mode = 'append';
end

%% preprocess Path list
if ischar(pathIn)
    outpathList    = regexp(pathIn,pathsep,'split');
    outpathList    = outpathList(~cellfun(@isempty,outpathList)); % kick out empty entries
elseif iscell(pathIn)
    outpathList = pathIn;
end

%% generate new file content
itaPathFile  = fullfile(userpath(),'ita_pathsToAddOnStartup.m');

switch mode
    case 'append'
        %get old content and add new path at the end
        fileContent = fileread(itaPathFile);
        fileContentCell = splitlines(fileContent);
        inserIdx = find(contains(fileContentCell,'];'));

        % add Info line with date information
        if ~any(contains(fileContentCell,sprintf(' %%%% ADDITIONAL PATH ENTRIES %s %%%%',datetime('now','Format','dd-MMM-yyyy'))))
            dateComment = sprintf(' %%%% ADDITIONAL PATH ENTRIES %s %%%%',datetime('now','Format','dd-MMM-yyyy'));
        end

        offset = 0; %needed when duplicates are found as offset between line and idx counter
        %insert new paths
        for idx = 1:numel(outpathList)
            pathStringInFile = sprintf(['''%s',pathsep,''' , ...'],outpathList{idx});
            %skip duplicates
            if ismember(pathStringInFile,fileContentCell)
                offset = offset-1;
                continue;
            end
            %add comment
            if exist('dateComment','var')
                pathStringInFile = strcat(pathStringInFile,dateComment);
                clear dateComment;
            end

            %add new paths
            fileContentCell{inserIdx+idx-1+offset} = pathStringInFile;
        end
        
        %add overwritten closing brackets
        fileContentCell{inserIdx+idx+offset} = sprintf('];');

    case 'replace'
        if exist(fullfile(userpath(),'ita_pathsToAddOnStartup.m'),'file')
            ita_verbose_info('ita_savepath::Overwriting existing ita_pathsToAddOnStartup.m file');
        end


        %overwrite with new paths
        fileContent = join(...
            [sprintf('function p = ita_pathsToAddOnStartup()\n'),...
            sprintf('p = [... \n'),...
            sprintf('%%%% ITA PATH ENTRIES %%%%\n'),...
            sprintf(['''%s',pathsep,''' , ...\n'],outpathList{:}),...
            sprintf('];') ]       );
        fileContentCell = splitlines(fileContent);
end

fileID = fopen(itaPathFile, 'w');
fprintf(fileID,'%s\n',fileContentCell{:});
fclose(fileID);
