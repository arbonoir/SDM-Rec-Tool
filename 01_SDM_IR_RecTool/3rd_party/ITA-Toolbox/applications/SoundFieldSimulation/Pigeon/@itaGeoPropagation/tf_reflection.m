function [ linear_freq_data ] = tf_reflection( obj, anchor, incident_direction_vec, emitting_direction_vec )
%TF_REFLECTION Returns the specular reflection transfer function for an reflection point anchor with
% an incident and emitting direction. Either impedance or absorption
% coefficients have to be present.

linear_freq_data = ones( obj.num_bins, 1 );


%% Checking if material and database are given and if material is in database
if ~isfield( anchor, 'material_id' )
    return
end

if ~isfield( obj.material_db, anchor.material_id )
    warning( 'Material id "%s" not found in database, skipping reflection tf calculation', anchor.material_id )
    return
end

material_data = obj.material_db.( anchor.material_id );

if ~isa( material_data, 'struct' )
    warning( 'Unrecognized material format "%s" of material with id "%s". Skipping tf calculation', ...
        class( material_data ), anchor.material_id )
    return
end

%% Get parameters
if isfield(material_data, 'absorption')
    absorption_coefficients = material_data.absorption;
else
    absorption_coefficients = 0;
end

if isfield(material_data, 'impedanceReal')
    impedance_coefficients = complex( material_data.impedanceReal, material_data.impedanceImag );
else
    impedance_coefficients = 0;
end


%% Calculation of transfer function
% If impedance values are given use impedance. Else use absorption values

if any(impedance_coefficients)
    % use impedance coeffs - complex
    linear_freq_data = tf_reflection_impedance(obj, impedance_coefficients, get_band_centers(absorption_coefficients, impedance_coefficients), incident_direction_vec, emitting_direction_vec);
elseif any(absorption_coefficients)
    % use absorption coeffs
    linear_freq_data = tf_reflection_absorption(obj, absorption_coefficients, get_band_centers(absorption_coefficients, impedance_coefficients));
else
    error(['There are no absorptiona AND no impedance coefficients given for material "' anchor.material_id '". At least one is needed.']);
end

return;
end


%%% ---------------------------------------------------------------------------------------------------------------------------------------------------------
%%% FUNCTIONS -----------------------------------------------------------------------------------------------------------------------------------------------
%%% ---------------------------------------------------------------------------------------------------------------------------------------------------------

%% small function to get band centers
function [band_centers] = get_band_centers(absorp_coeffs, imp_coeffs)
num_coeffs = max(length(absorp_coeffs), length(imp_coeffs));

switch num_coeffs
    case 10
        % Octave
        elevenCoeffs = ita_ANSI_center_frequencies([20 20000],1);
        band_centers = elevenCoeffs(2:end);
    case 31
        % Third Octave
        band_centers = ita_ANSI_center_frequencies([20 20000],3);
    otherwise
        error(['Could not determine Center Frequencies. Absorption coefficients for material "' anchor.material_id ...
            '" not given in Octave (10 values) or ThirdOctave (31 values) format. Given number of values was: "' int2str(num_coeffs) '".']);
end
end



%% calculate from impedance
% reflection coeff is:
%     impedace*cos(angle of incident to face normal) - Z_0
% R = ------------------------------------------------------
%     impedace*cos(angle of incident to face normal) + Z_0
% We have vec in and out. Calculate angle between them is double of the
% angle needed (because specular reflection has same incoming as outgoing
% angle. The angle of incident is:
%                  incident_vector * emitting_vector
% angle = arccos( ---------------------------------- )
%                 |incident_vector|*|emitting_vector|
function [linear_freq_data] = tf_reflection_impedance(obj, impedance_coefficients, band_centers, incident_direction_vec, emitting_direction_vec)
ita_propagation_load_defaults; % loads ita propagation default values as struct into workspace, called ita_propagation_defaults
Z_0 = ita_propagation_defaults.air.speed_of_sound * ita_propagation_defaults.air.density; % characteristic impedance of air

cos_of_angle_between_in_out = acos(incident_direction_vec' * emitting_direction_vec); % both vectors are already normed to one
% This is done because the vectors are 'not tail - tail'. One points to the origin of the other. We therefor calc the angle not between 
% their tails but some other stuff. look here https://www.cuemath.com/geometry/angle-between-vectors/. The incident
% points into face and emitting out of the face.
cos_of_angle_between_in_out = pi - cos_of_angle_between_in_out;
incident_angle = cos_of_angle_between_in_out / 2;

% calc reflection coeffs
reflection_coefficients = (impedance_coefficients .* cos(incident_angle) - Z_0) ./ ...
                          (impedance_coefficients .* cos(incident_angle) + Z_0);

% interpolate reflection coefficients
linear_freq_data_real = spline(band_centers, real(reflection_coefficients), obj.freq_vec);
linear_freq_data_imag = spline(band_centers, imag(reflection_coefficients), obj.freq_vec);
linear_freq_data = complex(linear_freq_data_real, linear_freq_data_imag);

% clamping?
if any(abs(linear_freq_data) > 1 - eps) || any(abs(linear_freq_data) < eps)
    mag = abs(linear_freq_data);
    pha = angle(linear_freq_data);
    
    mag(mag > 1 - eps) = 1 - eps;
    mag(mag < eps) = eps;
    linear_freq_data = mag .* exp(1i * pha);
end

end

%% calculate from absorption
function [linear_freq_data] = tf_reflection_absorption(obj, absorption_coefficients, band_centers)
reflection_coefficients = sqrt(1 - absorption_coefficients);

amplitude = spline(band_centers, reflection_coefficients, obj.freq_vec);

% Clamping
amplitude(amplitude > 1 - eps) = 1 - eps;
amplitude(amplitude < eps) = eps;

% Adding Minimal Phase via Hilbert Transformation
minimal_phase = hilbert(log(amplitude));
linear_freq_data = amplitude .* exp(1i*imag(minimal_phase));
end

