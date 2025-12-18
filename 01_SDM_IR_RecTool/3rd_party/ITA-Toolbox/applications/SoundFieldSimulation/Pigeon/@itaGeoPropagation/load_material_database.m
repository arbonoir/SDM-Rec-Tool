function [] = load_material_database(obj, pathDatabase, includeSubFolders)
%LOAD_MATERIAL_DATABASE Loads material files from a directory
%   Its better to use load_paths_and_materials as it takes the materials
%   directly from the file. This also probably crashes(?) if any of the
%   material values are not given

% Check if include_subfolders is provided
include_subfolders = true;
if nargin < 2
    include_subfolders = false;
end

% Search for .ini files in the specified directory and its subfolders
if include_subfolders
    ini_files = dir(fullfile(pathDatabase, '**/*.mat'));
else
    ini_files = dir(fullfile(pathDatabase, '*.mat'));
end

% Load each .ini file and store the data structure in a cell array
if isempty(ini_files)
    warning('No .mat files found in the directory and its subfolders');
end  

ini = IniConfig();
for i = 1:numel(ini_files)
    ini.ReadFile(fullfile(ini_files(i).folder, ini_files(i).name));
    name = ini.GetValues('Material', 'name');
    absorp = ini.GetValues('Material', 'absorp');
    scatter = ini.GetValues('Material', 'scatter');
    impedanceReal = ini.GetValues('Material', 'impedanceReal');
    impedanceImag = ini.GetValues('Material', 'impedanceImag');
    interpol = ini.GetValues('Material', 'interpol');
    
    % Add to database
    data = struct('absorption', absorp, 'scatter', scatter, 'interpol', interpol, ...
        'impedanceReal', impedanceReal, 'impedanceImag', impedanceImag);
    obj.material_db.(name) = data;

end


end

