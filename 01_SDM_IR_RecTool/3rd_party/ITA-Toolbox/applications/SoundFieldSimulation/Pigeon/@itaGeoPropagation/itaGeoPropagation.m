classdef itaGeoPropagation < handle
    %ITAGEOPROPAGATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        %---General properties---
        
        pps;                                        %Propagation paths struct
        c = 341.0;                                  %Speed of sound
        diffraction_model = 'utd';                  %Model for diffraction filter
        sim_prop = struct();                        %Struct with simulation settings like maximum reflection/diffraction order
        eps_precision = eps;                        %Set appropriate for your model. Will be used to verify if point is inside wedge or not
        
        %---Transfer function properties---
        
        fs = 44100;                                 %Sampling frequency used for TF frequency vector
        
        %---Properties used to create auralization data---
        
        pps_old;                                    %Propagation paths of last time frame (only used for auralization parameters)
        source_id = 1;                              %Auralization source ID
        receiver_id = 1;                            %Auralization receiver ID
        freq_vector = ita_ANSI_center_frequencies'; %Frequency vector used for calculating auralization parameters
    end
    
   properties (Access = protected)
        n = 2^15 + 1;
        directivity_db = struct();
        material_db = struct();
   end
    
    properties (Dependent)
        freq_vec;   %Linear spaced frequency vector used for TF calculation
        num_bins;   %Number of bins used for TF calculation
    end
    
    methods
        
        function obj = itaGeoPropagation( fs, num_bins )            
           if nargin >= 1
                obj.fs = fs;            
           end           
           if nargin >= 2
                obj.n = num_bins;            
           end
           
           obj.sim_prop.diffraction_enabled = true;
           obj.sim_prop.reflection_enabled = true;
           obj.sim_prop.directivity_enabled = true;
           obj.sim_prop.orders.reflection = -1;
           obj.sim_prop.orders.diffraction = -1;
           obj.sim_prop.orders.combined = -1;
           
        end
        
        function eps_precision = get.eps_precision( obj )
            eps_precision = obj.eps_precision;
        end
        
        function set.eps_precision( obj, eps_in )
            obj.eps_precision = eps_in;
        end
        
        function fs = get.fs( obj )
            fs = obj.fs;
        end
        
        function num_bins = get.num_bins( obj )
            num_bins = obj.n;
        end
        
        function f = get.freq_vec( obj )
            % Returns frequency base vector
            
            % taken from itaAudio (ITA-Toolbox)
            if rem( obj.n, 2 ) == 0
                f = linspace( 0, obj.fs / 2, obj.n )';
            else
                f = linspace( 0, obj.fs / 2 * ( 1 - 1 / ( 2 * obj.n - 1 ) ), obj.n )'; 
            end
            
        end
        
        function material_data = get_material(obj, material_id)
            if ~isfield( obj.material_db, material_id )
                error('Material with id %s not found.', material_id);
            end
            material_data = obj.material_db.( material_id );
        end
        
    end
end
