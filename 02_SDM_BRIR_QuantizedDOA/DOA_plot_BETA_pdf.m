clear all
close all
clc

addpath(genpath('../SDMtools/'));
addpath(genpath('../data/'));
addpath(genpath('functions/'));

%% load recorded data

% lade Daten mit mat file
filepath='../data/RIRs/';
%filepath='D:\Daten\DORAV\Parameter\SDM_M\';
%filepath='D:\Daten\Grids_H2505_AVLAB_RedRaum\jonathan_ML2102\'


Files=dir([filepath,'*.mat']);

if(length(Files)>1)
    for idx=1 : length(Files)
        disp([num2str(idx),': ',Files(idx).name])
    end
    prompt = 'select file number which should be loaded:';
    kselect=input(prompt);
else
    kselect=1;
end


filename=Files(kselect).name;

%5irs=load([filepath filename]);
load([filepath filename]);


clear newData;
Dcount = 0;

for idxSpeaker=1 : length(irs.speakerNames)
    
    fs              = double(irs.fs);    % Sampling Rate (in Hz). Only 48 kHz is recommended. Other sampling rates have not been tested.
    
    %RAUMABHÄNGIG----------------------------------------------------------
    MixingTime      = 0.1;                 % Mixing time (in seconds) of the room for rendering. Data after the mixing time will be rendered
    BRIRLength      = 0.25;                  % Duration of the rendered BRIRs (in seconds)

    SpeedSound      = 345;                  % Speed of sound in m/s (for SDM Toolbox DOA analysis)
    
    ArrayGeometry = [1 0 0;
                     0 -0.7071 -0.7071;
                     0 -0.7071 0.7071;
                     -1 0 0;
                     0 0.7071 0.7071;
                     %0 0.7071 -0.7071;
                     0 0 0] * (0.1/2);
    
    SDM_Struct = createSDMStruct('c',SpeedSound,...
        'fs',irs.fs,...
        'micLocs',ArrayGeometry,...
        'winLen',62);
     
    SRIR = irs.ir{idxSpeaker}(:,:);

    %figure
    %for idxIR = 1 : 7
    %    nexttile
    %    plot(SRIR(2300:2500,idxIR))
    %end
    %if(0)
    %    SRIR(:,7)=-SRIR(:,7);
    %end
   
    
    %f_gain = [5.899974163771157,5.960146874493056,3.669551814562449,4.178224276367109,3.710109648676412,5.230395430311390,1]; %Messung RMS von IR
    %SRIR = SRIR .* f_gain;
   
     
    SRIR=SRIR(:,[1,2,3,4,5,7]);
    
    DOA = SDMPar(SRIR, SDM_Struct);
    P = SRIR(:,6);




    %PLOT
    res = 1; % DOA resolution of the polar response
    t_steps = 1; %in ms


    ir_threshold = 0.5; % treshold level for the beginning of direct sound

    %Find the direct sound
    ind = find(abs(P)/max(abs(P)) > ir_threshold,1,'first');
    pre_threshold = round(0.001*fs); % go back 1 ms
    t_ds = ind - pre_threshold; % direct sound begins from this sample

    % make sure that the time index of direct sound is greater than or equal to 1
    t_ds = max(t_ds, 1);

    t_end = MixingTime/(t_steps/1000);


    ts = round( 1 : (t_steps/1000*fs) : ((t_end+1)*(t_steps/1000*fs)) );


    t = ts(2:end)/fs;
    %t = round( 1 : (t_steps/1000*fs) : length(P{idx_s})-t_ds );


    %t_end = length(P{idx_s});

    % Iterate through different time windows
    clear HS
    for k = 1:length(ts)-1

        t1 = t_ds+ts(k);
        t2 = t_ds+ts(k+1);
        tmpDOA = DOA(t1:t2,:);
        tmpP = P(t1:t2);

        %t2 = min(t_ds+t(k),(t_end/1000*fs));
        %tmpDOA = DOA{idx_s}(t2:(t_end/1000*fs),:);
        %tmpP = P{idx_s}(t2:(t_end/1000*fs));

        az_corr = 0;
        el_corr = 0;

        [az,el,~] = cart2sph(tmpDOA(:,1),tmpDOA(:,2),tmpDOA(:,3));
        [x,y,z] = sph2cart(az+az_corr,el+el_corr,1);
        [az,el,~] = cart2sph(x,y,z);

        % Find the closest direction in the grid for each image-source
        AZ = round(az(:)*180/pi/res)*res;
        EL = round(el(:)*180/pi/res)*res;

        %AZ = round(rad2deg(az(:))/res)*res;
        %EL = round(rad2deg(el(:))/res)*res;

        % Pressure to energy
        A2 = tmpP.^2;
        A2 = A2(:);

        % Doughnut weighting for angles, i.e. cosine weighting
        doa_az_vec = -180:res:180;
        doa_el_vec = -90:res:90;

        H = zeros(length(doa_az_vec), length(doa_el_vec));

        for idx = 1 : length(A2)
            if( ~((isnan(AZ(idx))) && (isnan(EL(idx)))) )
                idxAz=find(AZ(idx)==doa_az_vec);
                idxEl=find(EL(idx)==doa_el_vec);
                H(idxAz,idxEl) = H(idxAz,idxEl) + A2(idx);
            end
        end
        HS(:,:,k) = H;

    end

    %%
    HS_sum = sum(HS,3);
    HS_sum = HS_sum./max(max(HS_sum));

    lim = -50;
    
    E = HS_sum';
    E_db = 10*log10(E);
    E_db=E_db;
    E_db(E_db<=lim)=lim;
    E_db_n = E_db - min(min(E_db));
    E_db_n = E_db_n./max(max(E_db_n));


    az = doa_az_vec;
    el = doa_el_vec;

    [AZ, EL] = meshgrid(az, el);
    
    R0 = 1;
    R_mod = R0 + 0.5 * E_db_n;
    [X, Y, Z] = sph2cart(deg2rad(AZ), deg2rad(EL), R_mod);


    figure
    surf(X, Y, Z, E_db, 'EdgeColor', 'interp','FaceColor','interp');
    axis equal;
    colormap('jet')
    colorbar;
    xlabel('X'); ylabel('Y'); zlabel('Z');
    title('Energieverteilung auf Kugeloberfläche');
    





    if(0)
        %---
        if(0)
            E = [HS_sum(:,end:-1:1),HS_sum,HS_sum(:,end:-1:1);
                HS_sum(:,end:-1:1),HS_sum,HS_sum(:,end:-1:1);
                HS_sum(:,end:-1:1),HS_sum,HS_sum(:,end:-1:1)];

            [lE,wE]=size(E);
            xE = 1:1:lE;
            yE = 1:1:wE;
            [XE, YE] = meshgrid(xE, yE);

            M = lE;
            N = wE;

            xEq = linspace(min(xE), max(xE),M);
            yEq = linspace(min(yE), max(yE), N);
            [XEq, YEq] = meshgrid(xEq, yEq);

            VE = interp2(XE, YE, E', XEq, YEq, 'cubic');

            Vq = VE(round(N/3):1:round(N*(2/3)),M/3:1:M*(2/3)-1);
            Vq = 10*log10(Vq.^2);

            [lx,ly]=size(Vq);
            xEq = linspace(0, 360,lx);
            yEq = linspace(-90, 90, ly);
            [AZq, ELq] = meshgrid(xEq, yEq);

            R = 1;
            [Xq, Yq, Zq] = sph2cart(deg2rad(AZq), deg2rad(ELq), R);

            figure
            surf(Xq, Yq, Zq, Vq', 'EdgeColor', 'none');
            colormap('copper')
            axis equal;
            colorbar;
            xlabel('X'); ylabel('Y'); zlabel('Z');
            title('Energieverteilung auf Kugeloberfläche');

        end

        [l,w]=size(HS_sum);
        M = l;
        N = w;

        azq = linspace(min(az), max(az),M);
        elq = linspace(min(el), max(el), N);
        [AZq, ELqG] = meshgrid(azq, elq);

        Vq = interp2(AZ, EL, HS_sum', AZq, ELqG, 'cubic');
        Vq = 10*log10(Vq.^2);
        [Xq, Yq, Zq] = sph2cart(deg2rad(AZq), deg2rad(ELqG), R);

        figure
        surf(X, Y, Z, 10*log10(HS_sum'), 'EdgeColor', 'none');
        axis equal;
        colormap('jet')
        colorbar;
        xlabel('X'); ylabel('Y'); zlabel('Z');
        title('Energieverteilung auf Kugeloberfläche');

        figure
        surf(Xq, Yq, Zq, Vq, 'EdgeColor', 'none');
        colormap('copper')
        axis equal;
        colorbar;
        xlabel('X'); ylabel('Y'); zlabel('Z');
        title('Energieverteilung auf Kugeloberfläche');

    end
end



