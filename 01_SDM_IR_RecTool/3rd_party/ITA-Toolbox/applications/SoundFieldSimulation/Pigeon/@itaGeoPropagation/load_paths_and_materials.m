function load_paths_and_materials(obj, json_file_path)
%LOAD_PATHS_AND_MATERIALS load propagation paths and materials from json
%file. 
%   Reads in the propagation path list and adds them to obj. Additionally
%   loads all available materials from the json and stores them in
%   obj.material_db

% load paths
obj.load_paths(json_file_path);

json_txt = fileread( json_file_path );
json_struct = jsondecode( json_txt );

% load materials
if ~isfield( json_struct, 'material_database' )
    error( 'Could not import materials from file %s, structure is missing field "material_database"', json_file_path )
end

obj.material_db = json_struct.material_database;



end

