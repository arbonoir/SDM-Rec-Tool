function [ linear_freq_data ] = tf_directivity( obj, anchor, wave_front_direction )
%TF_DIRECTIVITY Returns the directivity transfer function for an anchor and
%a target (incoming or outgoing wave front direction relative (not in world coordinates!) to anchor point)

assert( isa( anchor, 'struct' ) )

linear_freq_data = ones( obj.num_bins, 1 );

if ~isfield( anchor, 'directivity_id' )
    return
end

if ~isfield( obj.directivity_db, anchor.directivity_id )
    warning( 'Directivity id "%s" not found in database, skipping directivity tf calculation', anchor.directivity_id )
    return
end

directivity_t = obj.directivity_db.( anchor.directivity_id );
directivity_data = directivity_t.data;

q_object = quaternion( anchor.orientation );
v = wave_front_direction( 1:3 ) / norm( wave_front_direction( 1:3 ) );
q_target = quaternion.rotateutov( [ 0 0 -1 ], v );
% q_combined = q_target * conj( q_object );
q_combined = q_target *  q_object ;

euler_angles = q_combined.EulerAngles( 'YXZ' );
azi_deg = rad2deg( real( euler_angles( 1 ) ) );
ele_deg = rad2deg( real( euler_angles( 2 ) ) );

% fprintf( 'Directivity used: azimuth=%.1f, elevation=%.1f for v=[%.1f %.1f %.1f]; q=[%.1f %.1f %.1f %.1f]\n', round( azi_deg, 1 ), round( ele_deg, 1 ),v, q_combined.double );

if isa( directivity_data, 'DAFF' )
    idx = directivity_data.nearest_neighbour_index( azi_deg, ele_deg );
    
    if strcmpi( directivity_data.properties.contentType, 'ir' )
        
        directivity_ir = directivity_data.record_by_index( idx )';
        directivity_dft = fft( directivity_ir, obj.num_bins * 2 - 1 ); % odd DFT length
        directivity_hdft = directivity_dft( 1:( ceil( obj.num_bins ) ), : );
        
        if any( strcmpi( directivity_t.eq_type, { 'custom', 'front' } ) )
            linear_freq_data = directivity_hdft .* directivity_t.eq_filter;
        elseif strcmpi( directivity_t.eq_type, { 'gain' } )
            linear_freq_data = directivity_hdft .* directivity_t.eq_gain;
        elseif strcmpi( directivity_t.eq_type, { 'delay' } )
            phase_by_delay = [ 1; exp( -1i .* 2 * pi * obj.freq_vec( 2:end ) * directivity_t.eq_delay ) ];
            linear_freq_data = directivity_hdft ./ phase_by_delay;
        elseif strcmpi( directivity_t.eq_type, { 'none' } )
            linear_freq_data = directivity_hdft;
        else
            warning 'Unknown equalization for directivity, using untouched data instead'
            linear_freq_data = directivity_hdft;
        end
        
    elseif strcmpi (directivity_data.properties.contentType, 'ms')
        % Third Octave
        band_centers = [20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, ...
            1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000, 20000];
        % get coeffs for index
        directivity_coeffs = directivity_data.record_by_index( idx )';
        ms = spline(band_centers, directivity_coeffs, obj.freq_vec);
        
        ms(ms < eps) = eps;
        % add minimal phase
        minimal_phase = hilbert(log(ms));
        linear_freq_data = ms .* exp(1i*imag(minimal_phase));
        
    else
        warning( 'Unrecognized DAFF content type "%s" of directivity with id "%s"', directivity_data.properties.contentType, anchor.directivity_id )
    end

elseif isa( directivity_data, 'itaAudio' )
    % itaCoordinates define the north pole at theta = 0; range of [0 180].
    % The calculation above returns the elevation/theta in the range of
    % [-90 90].
    ele_deg = ele_deg + 90;

    if isa( directivity_data, 'itaHRTF' )
        direction_data = directivity_data.findnearestHRTF(ele_deg, azi_deg);
    else
        mean_radius = mean(directivity_data.channelCoordinates.r);
        direction_idx = directivity_data.channelCoordinates.findnearest([mean_radius, deg2rad(ele_deg), deg2rad(azi_deg)], 'sph', 1);
        direction_data = directivity_data.ch( direction_idx );
    end

%     fprintf( 'Directivity picked: azimuth=%.1f, elevation=%.1f cart=[%.1f %.1f %.1f] for v=[%.1f %.1f %.1f]\n',...
%         direction_data.channelCoordinates.theta_deg,...
%         direction_data.channelCoordinates.phi_deg,...
%         direction_data.channelCoordinates.cart,...
%         v);

    direction_data.nSamples = 2 * (obj.num_bins - 1);

    linear_freq_data = direction_data.freq;
else
    warning( 'Unrecognized directivity format "%s" of directivity with id "%s"', class( directivity_data ), anchor.directivity_id )
end

end

