clear all
close all
clc

addpath(genpath('../SDMtools/'));
addpath(genpath('../data/'));
addpath(genpath('functions/'));

%% load recorded data2


% lade Daten mit mat file
filepath='../data/RIRs/';


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
load([filepath filename])


for idxSpeaker=1 : length(irs.speakerNames)
    
    MicArray        = 'SDM';                % FRL Array is 7 mics, 10cm diameter, with central sensor. Supported geometries are FRL_10cm, FRL_5cm,
    % Tetramic and Eigenmike. Modify the file create_MicGeometry to add other geometries (or contact us, we'd be happy to help).
    
    Room            = irs.room;                 % Name of the room. RIR file name must follow the convention RoomName_SX_RX.wav
    SourcePos       = irs.speakerNames{idxSpeaker};    % Source Position. RIR file name must follow the convention RoomName_SX_RX.wav
    ReceiverPos     = [num2str(irs.micPos(1)), '_', num2str(irs.micPos(2)),'_',num2str(irs.micPos(3))]; % Receiver Position. RIR file name must follow the convention RoomName_SX_RX.wav
    
    %SourcePos   = ['SX_',num2str(irs.speakerPos{idx}(1)),'_',num2str(irs.speakerPos{idx}(2)),'_',num2str(irs.speakerPos{idx}(3))];
    %ReceiverPos = ['RX_',num2str(irs.micPos(1)), '_', num2str(irs.micPos(2)),'_',num2str(irs.micPos(3))]; % Receiver Position. RIR file name must follow the convention RoomName_SX_RX.wav
    
    Database_Path   = '../data/RIRs';   % Relative path to folder containing the multichannel RIR
    
    fs              = irs.fs;    % Sampling Rate (in Hz). Only 48 kHz is recommended. Other sampling rates have not been tested.
    
    %RAUMABHÄNGIG----------------------------------------------------------
    MixingTime      = 0.5;                 % Mixing time (in seconds) of the room for rendering. Data after the mixing time will be rendered
    % as a single direction independent reverb tail and AP rendering will be applied.
    DOASmooth       = 16;                   % Window length (in samples) for smoothing of DOA information. 16 samples is a good compromise for noise
    % reduction and time resolution.
    BRIRLength      = 0.25;                  % Duration of the rendered BRIRs (in seconds)
    
    
    
    DenoiseFlag     = 0;                    % Flag to perform noise floor compensation on the multichannel RIR. This ensures that the RIR decays
    % progressively and removes rendering artifacts due to high noise floor in the RIR.
    FilterRawFlag   = 1;                    % Flag to perform band pass filtering on the multichannel RIR prior to DOA estimation. If active, only
    % information between 200Hz and 8kHz (by default) will be used for DOA estimation. This helps increasing
    % robustness of the estimation. See create_BRIR_data.m for customization of the filtering.
    AlignDOA        = 0;                    % If this flag is set to 1, the DOA data will be rotated so the direct sound is aligned to 0,0 (az, el).
    SpeedSound      = 345;                  % Speed of sound in m/s (for SDM Toolbox DOA analysis)
    WinLen          = 62;                   % Window Length (in samples) for SDM DOA analysis. For fs = 48kHz, sizes between 36 and 64 seem appropriate.
    % The optimal size might be room dependent. See Tervo et al. 2013 and Amengual et al. 2020 for a discussion.
    
    IR_exp = irs.ir{idxSpeaker}(:,:);
    
    [ze,sp]=size(IR_exp);
    if(sp>ze)
        IR_exp=IR_exp';
    end
    
    audiowrite( [Database_Path filesep MicArray,'_',Room,'_',SourcePos,'_',ReceiverPos,'.wav'],IR_exp,fs,'BitsPerSample',32);
    clear IR_exp;
    
    
    SRIR_data = create_SRIR_data('MicArray', MicArray,...
        'Room',Room,...
        'SourcePos',SourcePos,...
        'ReceiverPos',ReceiverPos,...
        'Database_Path',Database_Path,...
        'fs',fs,...
        'MixingTime',MixingTime,...
        'DOASmooth',DOASmooth,...
        'Length',BRIRLength,...
        'Denoise',DenoiseFlag,...
        'FilterRaw',FilterRawFlag,...
        'AlignDOA',AlignDOA);
    
    SDM_Struct = createSDMStruct('c',SpeedSound,...
        'fs',irs.fs,...
        'micLocs',SRIR_data.ArrayGeometry,...
        'winLen',62);
    
    delete([Database_Path filesep MicArray,'_',Room,'_',SourcePos,'_',ReceiverPos,'.wav'])
    
    
    SRIR_data.DOA = SDMPar(SRIR_data.Raw_RIR, SDM_Struct);
    
    
    %%PLOT
    
    idx_s=1;
    
    DOA{idx_s} = SRIR_data.DOA;
    P{idx_s} = SRIR_data.Raw_RIR(:,7);
    
    maxdB = max(10*log10(P{idx_s}.^2));
    
    %%einstellen
    res = 3; % DOA resolution of the polar response
    t_steps = 0.5; %in ms
    
    t_start = 0; %in ms
    t_end = 100; %in ms
    
     
    ir_threshold = 0.5; % treshold level for the beginning of direct sound
     
    %Find the direct sound
    ind = find(abs(P{idx_s})/max(abs(P{idx_s})) > ir_threshold,1,'first');
    pre_threshold = round(0.001*fs); % go back 1 ms
    t_ds = ind - pre_threshold; % direct sound begins from this sample
    
    % make sure that the time index of direct sound is greater than or equal to 1
    t_ds = max(t_ds, 1);
    
    
    ts = round( ((t_start/1000*fs)+1) : (t_steps/1000*fs) : (t_end/1000*fs)+(t_steps/1000*fs) );
    
    %t = round( 1 : (t_steps/1000*fs) : length(P{idx_s})-t_ds );
    
    
    %t_end = length(P{idx_s});
    
    % Iterate through different time windows
    for k = 1:length(ts)-1
        
        t1 = t_ds+ts(k);
        t2 = t_ds+ts(k+1);
        tmpDOA = DOA{idx_s}(t1:t2,:);
        tmpP = P{idx_s}(t1:t2);
        
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
        
        % Pressure to energy
        A2 = tmpP.^2;
        A2 = A2(:);
        
        % Doughnut weighting for angles, i.e. cosine weighting
        doa_az_vec = -180:res:180;
        doa_el_vec = -90:res:90;
        
        H = zeros(length(doa_az_vec), length(doa_el_vec));

        for idx_az = 1:  length(doa_az_vec)
            for idx_el = 1 : length(doa_el_vec)
                
                inds_az = (AZ == doa_az_vec(idx_az));
                inds_el = (EL == doa_el_vec(idx_el));
                                
                H(idx_az,idx_el) = nansum(A2(inds_az & inds_el));
                
            end
        end
        
        HS(:,:,k) = H;
    end
    

    noisefloor_dB = -100;
    %maxdB = 10*log10(max(max(max(HS))));
    %ges_dB = 10*log10(sum(HS,'all'));
    %mph = 0.0001*(10^(maxdB/10));
    mph = 10^(noisefloor_dB/10);
    
    
    az_tic =-180 :30: 180;
    el_tic =-90 :30: 90;
    
    Scale = 1000;
    
    %Vorbereitung Plot DoA IR^2
    for idxk = k : -1 : 1
        
        tmpH =  HS(:,:,idxk);
                
        count=0;
        for idx = 1:size(tmpH,1)
            if(find(tmpH(idx,:)>mph,1))
                [pks,loc] = findpeaks(tmpH(idx,:),'MinPeakHeight',mph);
                %[pks,loc] = findpeaks(tmpH(idx,:));
                if(~isempty(pks))
                    for idxC = 1 : length(pks)
                        count=count+1;
                        %location az el
                        idxPeaksAzEl(count,:)=[idx,loc(idxC)];
                    end
                end
            end
        end
        
        for idx = 1 : count
            tmpA2(idx) = tmpH(idxPeaksAzEl(idx,1),idxPeaksAzEl(idx,2));
        end
        
        if(count~=0)
            peak_Az_El_R(idxk)={[idxPeaksAzEl,tmpA2']};  
        end
        clear A tmpA2 idxPeaksAzEl tmpH;
    end
    
    
    
    
    
    %light and dark mode
    
    plot_mode = "dark";
    %Sense_of_Rotation_Az = "clockwise"
    Sense_of_Rotation_Az = "counterclockwise";
    
    switch(plot_mode)
        case "dark"
            cmap = colormap('hot');
            stepw_color = floor(230/(length(ts)-1));
            %newcolors = cmap(1:stepw_color:256,:);
            newcolors = cmap(230:-stepw_color:1,:);
            BackColor = [0.1 0.1 0.1];
            GridColor = [0.9 0.9 0.9];
            AlphaColor = 0.8;
        case "light"
            cmap = colormap('jet');
            stepw_color = floor(230/(length(ts)-1));
            newcolors = cmap(1:stepw_color:230,:);
            %newcolors = cmap(230:-stepw_color:1,:);
            BackColor = [1 1 1];
            GridColor = [0.1 0.1 0.1];
            AlphaColor = 0.8;
        otherwise
    end
    
    if(length(newcolors)<length(ts))
       error('Farbabstufung zu klein') 
    end
    close 
    
    %% Plot abs(IR)(abs pressure) over time
    figP=figure;
    set(figP,'defaultfigurecolor',[1 1 1]);
    for k = 1:length(ts)-1
        t1 = t_ds+ts(k);
        t2 = t_ds+ts(k+1);
        plot((ts(k):ts(k+1))/fs,(abs(P{idx_s}(t1:t2)/max(abs(P{idx_s})))),'Color',[newcolors(k,:) AlphaColor])
        %plot((ts(k):ts(k+1))/fs,10*log10(abs(P{idx_s}(t1:t2)/max(abs(P{idx_s}))).^2),'Color',[newcolors(k,:) AlphaColor])
        %t2 = min(t_ds+t(k),(t_end/1000*fs));
        %plot((t2:(t_end/1000*fs)),P{idx_s}(t2:(t_end/1000*fs)),'Color',newcolors(k,:))
        hold on
    end
    grid on
    hold off
    xlim([0 t_end/1000])
    xlabel('time in s')
    ylabel('absolute amplitude')
    title(irs.room)
    
    ax = gca;
    ax.Color = BackColor;
    ax.GridColor = GridColor;
    
    close
    
    
    %% Plot DoA IR (abs pressure)
    %DefFonSiz = 10;
        
    figP = figure;
    %set(figP, 'Position', [300, 150, 1024, 768],'defaultfigurecolor',[1 1 1],'DefaultAxesFontSize',DefFonSiz);
    set(figP, 'Position', [300, 150, 1024, 496],'defaultfigurecolor',[1 1 1]);
    
    %pic=imread('D:\Daten\PWHoertest_2021\H1562_E.jpg');
    %imagesc(180:-res:-180,-90:res:90,pic)
    %hold on
    
    for idxk = length(peak_Az_El_R) : -1 : 1
        
        tmp = peak_Az_El_R{idxk};
        if(~isempty(tmp))
            
            A =sqrt(tmp(:,3)./((10^(maxdB/10))))*Scale;
            tmp=tmp(A~=0,:);
            
            scatter(doa_az_vec(tmp(:,1)),doa_el_vec(tmp(:,2)),A,'filled','MarkerFaceColor',newcolors(idxk,:),'MarkerFaceAlpha',AlphaColor)
            hold on
        end
    end
    grid on
    xticks(az_tic)
    yticks(el_tic)
    xlim([-180 180])
    ylim([-90 90])
    title(irs.room)
    xlabel("azimuth in degree")
    ylabel("elevation in degree")
    switch(Sense_of_Rotation_Az)
        case 'clockwise'
            view([0 90])
        case 'counterclockwise'
            view([180 -90])
        otherwise
    end
    ax = gca;
    ax.Color = BackColor;
    ax.GridColor = GridColor;
    
    
    
    %% plot hist az und el over time
        
    tmp = sqrt(HS);
    
    [s_az, s_el, s_t] = size(HS);
 
    tmpAz = squeeze(sum(tmp,2));
    %tmpAz = tmpAz/max(max(tmpAz)); %Normiert auf direktschall
    tmpAz = tmpAz/max(sum(tmpAz,2)); %Normiert auf über die Zeit summierte absolute amplitude  
    
    tmpEl = squeeze(sum(tmp,1));
    %tmpEl = tmpEl/max(max(tmpEl)); %Normiert auf direktschall
    tmpEl = tmpEl/max(sum(tmpEl,2)); %Normiert auf über die Zeit summierte absolute amplitude  
 
    figP = figure;
    set(figP, 'Position', [300, 150, 1024, 496],'defaultfigurecolor',[1 1 1]);
    bp=bar(tmpAz,'stacked','FaceColor','flat');
    for k = 1:s_t
        bp(k).FaceColor = newcolors(k,:);
    end
    ylim([0 1])
    xticks(1 : (s_az-1)/(length(az_tic)-1) : s_az)
    xticklabels(az_tic)
    xlim([1 s_az])
    xlabel("azimuth in degree")
    ylabel("summed normalized absolute amplitude")
    switch(Sense_of_Rotation_Az)
        case 'clockwise'
            view([0 90])
        case 'counterclockwise'
            view([180 -90])
        otherwise
    end
    grid on
    ax = gca;
    ax.Color = BackColor;
    ax.GridColor = GridColor;
    
    close
 
    figP = figure;
    set(figP, 'Position', [300, 150, 512, 496],'defaultfigurecolor',[1 1 1]);
    bp=bar(tmpEl,'stacked','FaceColor','flat');
    for k = 1:s_t
        bp(k).FaceColor = newcolors(k,:);
    end
    ylim([0 1])
    xticks(1 : (s_el-1)/(length(el_tic)-1) : s_el)
    xlim([1 s_el])
    xticklabels(el_tic)
    xlabel("elevation in degree")
    ylabel("summed normalized absolute amplitude")
    view([90 -90])
    grid on
    ax = gca;
    ax.Color = BackColor;
    ax.GridColor = GridColor;
    
    close 
    
    %% plot All in one
    
    DefFonSiz=14;
    figP = figure;
    %set(figP, 'Position', [0, 0, 1500, 1100],'defaultfigurecolor',[1 1 1]);
    set(figP, 'Position', [0, 0, 1500, 1100],'defaultfigurecolor',[1 1 1],'DefaultAxesFontSize',DefFonSiz);

    tiledplot=tiledlayout(2,3);
    tiledplot.TileSpacing = 'compact';
    %title(tiledplot,irs.room,'FontWeight','bold')
    title(tiledplot,['room: ',char(irs.room),'; speaker name: ',char(irs.speakerNames(idxSpeaker))],'FontWeight','bold','FontSize',DefFonSiz+2);
    
    nexttile
    % p over el
    bp=bar(tmpEl,'stacked','FaceColor','flat');
    for k = 1:s_t
        bp(k).FaceColor = newcolors(k,:);
    end
    ylim([0 1])
    xticks(1 : (s_el-1)/(length(el_tic)-1) : s_el)
    xlim([1 s_el])
    xticklabels(el_tic)
    xlabel("elevation in degree")
    ylabel("summed normalized absolute amplitude")
    view([90 -90])
    grid on
    ax = gca;
    ax.Color = BackColor;
    ax.GridColor = GridColor;
    
    nexttile([1 2])
    %Kreisplot az el
    for idxk = length(peak_Az_El_R) : -1 : 1
        
        tmp = peak_Az_El_R{idxk};
        if(~isempty(tmp))
            
            A =sqrt(tmp(:,3)./((10^(maxdB/10))))*Scale;
            tmp=tmp((A~=0),:);
            
            scatter(doa_az_vec(tmp(:,1)),doa_el_vec(tmp(:,2)),A,'filled','MarkerFaceColor',newcolors(idxk,:),'MarkerFaceAlpha',AlphaColor)
            hold on
        end
    end
    grid on
    xticks(az_tic)
    yticks(el_tic)
    xlim([-180 180])
    ylim([-90 90])
    xlabel("azimuth in degree")
    ylabel("elevation in degree")
    switch(Sense_of_Rotation_Az)
        case 'clockwise'
            view([0 90])
        case 'counterclockwise'
            view([180 -90])
        otherwise
    end
    ax = gca;
    ax.Color = BackColor;
    ax.GridColor = GridColor;
    
    nexttile
    %plot IR
    for k = 1:length(ts)-1
        t1 = t_ds+ts(k);
        t2 = t_ds+ts(k+1);
        plot((ts(k):ts(k+1))/fs,(abs(P{idx_s}(t1:t2)/max(abs(P{idx_s})))),'Color',[newcolors(k,:) AlphaColor])
        %plot((ts(k):ts(k+1))/fs,10*log10(abs(P{idx_s}(t1:t2)/max(abs(P{idx_s}))).^2),'Color',[newcolors(k,:) AlphaColor])
        %t2 = min(t_ds+t(k),(t_end/1000*fs));
        %plot((t2:(t_end/1000*fs)),P{idx_s}(t2:(t_end/1000*fs)),'Color',newcolors(k,:))
        hold on
    end
    grid on
    hold off
    xlim([t_start/1000 t_end/1000])
    ylim([0 1])
    xlabel('time in s')
    ylabel('absolute amplitude')
    ax = gca;
    ax.Color = BackColor;
    ax.GridColor = GridColor;
    
    nexttile([1 2])
    
    bp=bar(tmpAz,'stacked','FaceColor','flat');
    for k = 1:s_t
        bp(k).FaceColor = newcolors(k,:);
    end
    ylim([0 1])
    xticks(1 : (s_az-1)/(length(az_tic)-1) : s_az)
    xticklabels(az_tic)
    xlim([1 s_az])
    xlabel("azimuth in degree")
    ylabel("summed normalized absolute amplitude")
    switch(Sense_of_Rotation_Az)
        case 'clockwise'
            view([0 90])
        case 'counterclockwise'
            view([180 -90])
        otherwise
    end
    grid on
    ax = gca;
    ax.Color = BackColor;
    ax.GridColor = GridColor;
    
    
    
end











if(0)
    
    if(0)
        % The Raw RIR and DOA data need to be cropped now, after the DOA and
        % diffuseness estimation. If the first sample in the raw RIR is already
        % the direct  sound, the DOA estimation is wrong - it does not find a
        % solution and returns 0º,0º.
        SRIR_data.Raw_RIR = SRIR_data.Raw_RIR(SRIR_data.DSonset:end,:);
        SRIR_data.DOA = SRIR_data.DOA(SRIR_data.DSonset:end,:);
        
        disp('Smoothing DOA data'); tic;
        SRIR_data = Smooth_DOA(SRIR_data);
        timer = toc;
        disp(['Done! Time elapsed: ' num2str(timer) 'seconds']);
    end
    
  
    
    
    
    
    
    
    
    
    %[DOA_rad(:,1), DOA_rad(:,2), DOA_rad(:,3)] = cart2sph(SRIR_data.DOA(:,1), SRIR_data.DOA(:,2), SRIR_data.DOA(:,3));
    
    %DOA_rad =  DOA_rad(~isnan(DOA_rad(:,1)),:);
    %DOA_rad = DOA_rad(find(DOA_rad(:,3)~=0),:);
    
    
    %[B,ind]=sort(DOA_rad(:,3));
    
    %DOA_rad=DOA_rad(ind,:);
    
    %cmap = colormap('turbo');
    %stepw_color = round(256/length);
    %newcolors = cmap(1:stepw_color:256,:);
    
    
    
    stepw=1;
    
    %Punkte im zeitbereich zusammen fassen und größe maker darüber definieren
    
    %impulsantwort durchgehen und energie für reflexionsteile berechnen
    
    %plot über az und el mit fabe über die Zeit
    
    
    %az
    %figure
    %plot((DOA_rad(1:stepw:end,3)/SpeedSound),rad2deg(DOA_rad(1:stepw:end,1)),'o')
    %polarscatter((DOA_rad(1:stepw:end,1)),DOA_rad(1:stepw:end,3)/SpeedSound)
    
    %el
    %figure
    %plot((DOA_rad(1:stepw:end,3)/SpeedSound),rad2deg(DOA_rad(1:stepw:end,2)),'o')
    
    figP = figure;
    set(figP, 'Position', [300, 150, 1024, 768/2],'DefaultAxesFontSize',12);
    scatter(rad2deg(DOA_rad(1:stepw:end,1)),rad2deg(DOA_rad(1:stepw:end,2)))
    grid on
    
    xticks(az_tic)
    yticks(el_tic)
    xlim([-180 180])
    ylim([-90 90])
    
    figP = figure;
    set(figP, 'Position', [300, 150, 1024, 768/2],'DefaultAxesFontSize',12);
    nx_bins=length(az_tic)*3;
    ny_bins= round(max(DOA_rad(:,3)/SpeedSound)/0.005);
    hist3([rad2deg(DOA_rad(1:stepw:end,1)),DOA_rad(1:stepw:end,3)/SpeedSound],'Nbins',[nx_bins ny_bins],'CDataMode','auto','FaceColor','interp')
    view(0.7109,-90)
    colorbar('southoutside')
    xticks(az_tic)
    xlim([-180 180])
    
    figP = figure;
    set(figP, 'Position', [300, 150, 1024/2, 768/2],'DefaultAxesFontSize',12);
    nx_bins=length(el_tic)*3;
    hist3([rad2deg(DOA_rad(1:stepw:end,2)),DOA_rad(1:stepw:end,3)/SpeedSound],'Nbins',[nx_bins ny_bins],'CDataMode','auto','FaceColor','interp')
    view(-90,90)
    colorbar('westoutside')
    xticks(el_tic)
    xlim([-90 90])
    
    
    tmp = (DOA_rad(:,3)/SpeedSound)*fs;
    
    %fenster definieren und in den bereich alle werte suchenn und richtung
    %zuordnen
    %zuordnung aus dem histogramm nehem und entsprechende energie aus den RIR zuordnen
    %und wichten nach der heufigkeit verteilung aus den richtungen
    
    tmp(1:end-1)-tmp(2:end)
    
    RIR = SRIR_data.P_RIR(:,1);
    figure
    plot(abs(RIR))
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    %figure
    %hist3([rad2deg(DOA_rad(1:stepw:end,1)),DOA_rad(1:stepw:end,3)/SpeedSound],'CDataMode','auto','FaceColor','interp')
    %colorbar
    %view(-90,90)
    %ylim([-90 90])
    
    if(0)
        step_wide = 2;
        DOA_rad_smal = DOA_rad(1:step_wide:end,:);
        t_smal = ts(1:step_wide:end);
        
        figure
        plot(t_smal,rad2deg(DOA_rad_smal(:,1)),'o')
        
        figure
        plot(t_smal,rad2deg(DOA_rad_smal(:,2)),'o')
        
        
        %polarscatter(DOA_rad(:,1),DOA_rad(:,3))
    end
    

end