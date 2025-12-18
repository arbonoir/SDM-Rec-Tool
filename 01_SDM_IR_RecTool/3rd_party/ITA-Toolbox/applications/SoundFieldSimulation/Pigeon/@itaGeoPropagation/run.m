function [ freq_data_linear, valid_paths, source_receiver_pairs ] = run( obj, with_progress_bar )
%RUN Calculates the transfer function (tf) of the superimposed (geometrical) propagation path in frequency domain

N = numel( obj.pps );
source_receiver_pairs = cell( N, 2 );
for n = 1:N
    pp = obj.pps( n );

    if iscell(pp.propagation_anchors(1))
        source_receiver_pairs{n,1} = pp.propagation_anchors{1}.name;
    else
        source_receiver_pairs{n,1} = pp.propagation_anchors(1).name;
    end

    if iscell(pp.propagation_anchors(end))
        source_receiver_pairs{n,2} = pp.propagation_anchors{end}.name;
    else
        source_receiver_pairs{n,2} = pp.propagation_anchors(end).name;
    end
end
source_receiver_pairs = unique( string(source_receiver_pairs), 'rows' );

% Prepage the result data structure
% Structure that maps a unique name for each source receiver pair to the
% frequency data.
% The name is in the form "<source_name>_X_<receiver_name>", where
% <source_name> and <receiver_name> are replaced by their respective
% names.
% Note, that the freq data here in only set to be one dimensional. When a
% directivity has more than one channel this will be handled by matlab
% automatically and the size will increase.
freq_data_linear = struct;
sr_fieldnames(size(source_receiver_pairs, 1)) = "";
for sr_idx = 1:size(source_receiver_pairs, 1)
    field_name = strjoin(source_receiver_pairs(sr_idx,:), '_X_');
    field_name = strrep(field_name, '.', '_');

    sr_fieldnames(sr_idx) = field_name;
    freq_data_linear.(field_name) = zeros( obj.num_bins, 1 );
end

if nargin < 2 || ~with_progress_bar
    with_progress_bar = false;
else
    h = waitbar( 0, 'Hold on, running propagation modeling' );
end

% Iterate over propagation paths, calculate transfer function and sum up

valid_paths = zeros( N, 1 );
for n = 1:N

    if with_progress_bar
        waitbar( n / N, h, sprintf('Path Nbr: %i/%i',n, N) );
    end

    pp = obj.pps( n );
    [ pp_tf, valid ] = obj.tf( pp );

    if iscell(pp.propagation_anchors(1))
        anchor1 = pp.propagation_anchors{1}.name;
    else
        anchor1 = pp.propagation_anchors(1).name;
    end

    if iscell(pp.propagation_anchors(end))
        anchor2 = pp.propagation_anchors{end}.name;
    else
        anchor2 = pp.propagation_anchors(end).name;
    end

    sr_idx = ismember(source_receiver_pairs, string({anchor1, anchor2}), 'rows');

    if valid
        freq_data_linear.(sr_fieldnames(sr_idx)) = freq_data_linear.(sr_fieldnames(sr_idx)) + pp_tf;
        if any( isnan( pp_tf ) )
            x = obj.tf( pp );
        end
    end
    valid_paths( n ) = valid;
            
end

if with_progress_bar 
    close( h )
end

end
