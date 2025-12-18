function blacksphere(otf, currentTrackingData, caseToPlot)
%BLACKSPHERE plots a sphere, rings, and icons of current position/orientation
%
%blacksphere([itaOptitrack] OptiTrack_object, 
%          [struct] currentTrackingData, 
%          [string] positionToPlot)
%   
%   
% [itaOptitrack] OptiTrack_object 
% [struct] currentTrackingData 
% [string] positionToPlot: 'initial' -- plot position to be reached
%                          'current' -- plot position to be corrected
%
% IMPORTANT:
% to get a proper plot of the blacksphere, please do the following steps:
% 1.) place the tracking body (Rigid Body 1) on the test subject's head
% 2.) place the test subject on the right position in the correct orientation
% 3.) calibrate the head of the test subject
%
% REMARKS:
% BLACKSPHERE uses tiledlayout (e.g. nexttile) introduced in MATLAB 2019b.
%
% Author:  Chalotorn Möhlmann
% Date:    2021-06-08
% Release: MATLAB 2019b

msg = 'Orientation and Position Feedback';

if strcmp(caseToPlot, 'initial')
    generate_figure_properties(otf); % add properties to figure
end

%% Position and orientation
calibHead = otf.optiTrackObject.dataCalibration.head;

% orientation
orient    = itaOrientation(1);
orient.qw = currentTrackingData.qw;
orient.qx = currentTrackingData.qx;
orient.qy = currentTrackingData.qy;
orient.qz = currentTrackingData.qz;
rolDiff  = orient.roll_deg  - calibHead.orientation.roll_deg;
pitDiff  = -(orient.pitch_deg - calibHead.orientation.pitch_deg);
yawDiff  = orient.yaw_deg   - calibHead.orientation.yaw_deg;

diffPos = otf.optiTrackObject.dataCalibration.headToEarAxisCenter.position;
len = norm([diffPos.x diffPos.y diffPos.z]);
% position
x_0 = currentTrackingData.x;
y_0 = currentTrackingData.y;
z_0 = currentTrackingData.z;
% pitch positional offset
y_pit = -len*cosd(pitDiff);
z_pit = len*sind(pitDiff);
% roll positional offset
y_rol = -len*cosd(rolDiff);
x_rol = -len*sind(rolDiff);
% Offset
x_ori = x_rol;
y_ori = 2*len+y_pit+y_rol;
z_ori = z_pit;
% relative position
xDiff    = (x_0-calibHead.position.x+x_ori)*10^2;      % convert m to cm
yDiff    = (y_0-calibHead.position.y+y_ori)*10^2;
zDiff    = (z_0-calibHead.position.z+z_ori)*10^2;

%% Tolerances to show whether subject hast to correct its position
% [smallTolerance, mediumTolerance, largeTolerance]
toleranceOrient = [     0.8,            1.5,            10;  ...      % in °C
    0.8,            1.5,            10;  ...
    0.6,            1.3,            10;       ];
tolerancePos    = [       1,            3.5,            5;   ...      % in cm
    1,            3.5,            2.5; ...
    1,            3.5,            5;        ];

%% Define plot colours
black     = 'k';
grey      = '#f0f0f0';
green     = [87/255,171/255,39/255];
yellow    = [246/255, 168/255, 0/255];
red       = [204/255, 7/255, 30/255];

%% Sphere
[x_sphere,y_sphere,z_sphere] = sphere(8);
r_sphe = 1.3;
r_ball = 0.1;
amp = 2; % amplify rotation

%% Circle
r_out = 1.43;    %outer radius
steps = 30;
theta = 0:2*pi/steps:2.1*pi;
r_outer = ones(size(theta))*r_out;
rr = r_outer;
theta = [theta;theta];
xx = rr.*cos(theta);
yy = rr.*sin(theta);
zz = zeros(size(xx));

%% Lighting and View
az = 90;
el = 0;
oriTile = 1;
oriGrid = [2 3];

%% ETC
unit = " mm";
fontSize = 20;
fontO = 18;
fontWeight = 'bold';

%% Patch and draw heads
if strcmp(caseToPlot, 'initial')
    t = tiledlayout(3,3);
    title(t, msg, 'FontSize', fontSize, 'FontWeight', fontWeight)
    
    nexttile(oriTile, oriGrid);
    hold on
    view([az el]);
    axis equal on
    axis([ -1  1    -1  1    -1  1]*1.5)
    yticklabels({'', 'left', '', '', '', 'right', ''})
    xticklabels({'', 'back', '', '', '', 'front', ''})
    zticklabels({'', 'down', '', '', '', 'up', ''})
    ax = gca;
    ax.Color = 'none';
    ax.FontSize = 16;
    grid off
    lWidth = 16;
    otf.(otf.figName).cir1 = surf(xx,yy,zz, 'Facecolor', green, 'EdgeColor', green, 'LineWidth', lWidth); % yaw
    otf.(otf.figName).cir2 = surf(xx,yy,zz, 'Facecolor', green, 'EdgeColor', green, 'LineWidth', lWidth); % roll
    otf.(otf.figName).cir3 = surf(xx,yy,zz, 'Facecolor', green, 'EdgeColor', green, 'LineWidth', lWidth); % pitch
    rotate(otf.(otf.figName).cir2,[0 1 0],90);
    rotate(otf.(otf.figName).cir3,[1 0 0],90);
    otf.(otf.figName).trol = text(r_out, r_out/1.6, r_out/1.8, 'roll', 'Rotation', -65, 'FontSize', fontO);
    otf.(otf.figName).tpit = text(r_out, 0.17, r_out/1.65, 'pitch', 'Rotation', -90, 'FontSize', fontO);
    otf.(otf.figName).tyaw = text(r_out, r_out/4, 0.17, 'yaw', 'FontSize', fontO);
    
    otf.(otf.figName).nstr = nexttile(7);
    hold on
    otf.(otf.figName).stng = imshow(imread('dummy.png'));
    otf.(otf.figName).strr = imshow(imread('dummy_right_red.png'));
    otf.(otf.figName).stlr = imshow(imread('dummy_left_red.png'));
    otf.(otf.figName).stry = imshow(imread('dummy_right.png'));
    otf.(otf.figName).stly = imshow(imread('dummy_left.png'));
    set(otf.(otf.figName).strr, 'Visible','off');
    set(otf.(otf.figName).stlr, 'Visible','off');
    set(otf.(otf.figName).stry, 'Visible','off');
    set(otf.(otf.figName).stly, 'Visible','off');
    otf.(otf.figName).nstr.XLabel.FontSize = fontSize;
    otf.(otf.figName).nstr.XLabel.FontWeight = fontWeight;
    axis image
    
    otf.(otf.figName).nele = nexttile(8);
    hold on
    otf.(otf.figName).elng = imshow(imread('dummy.png'));
    otf.(otf.figName).elur = imshow(imread('dummy_up_red.png'));
    otf.(otf.figName).eldr = imshow(imread('dummy_down_red.png'));
    otf.(otf.figName).eluy = imshow(imread('dummy_up.png'));
    otf.(otf.figName).eldy = imshow(imread('dummy_down.png'));
    set(otf.(otf.figName).elur, 'Visible','off');
    set(otf.(otf.figName).eldr, 'Visible','off');
    set(otf.(otf.figName).eluy, 'Visible','off');
    set(otf.(otf.figName).eldy, 'Visible','off');
    otf.(otf.figName).nele.XLabel.FontSize = fontSize;
    otf.(otf.figName).nele.XLabel.FontWeight = fontWeight;
    axis image
    
    otf.(otf.figName).nsur = nexttile(9);
    hold on
    otf.(otf.figName).sung = imshow(imread('dummy.png'));
    otf.(otf.figName).subr = imshow(imread('dummy_back_red.png'));
    otf.(otf.figName).sufr = imshow(imread('dummy_front_red.png'));
    otf.(otf.figName).suby = imshow(imread('dummy_back.png'));
    otf.(otf.figName).sufy = imshow(imread('dummy_front.png'));
    set(otf.(otf.figName).subr, 'Visible','off');
    set(otf.(otf.figName).sufr, 'Visible','off');
    set(otf.(otf.figName).suby, 'Visible','off');
    set(otf.(otf.figName).sufy, 'Visible','off');
    otf.(otf.figName).nsur.XLabel.FontSize = fontSize;
    otf.(otf.figName).nsur.XLabel.FontWeight = fontWeight;
    axis image
    
elseif strcmp(caseToPlot, 'current')
    % delete plots of old frame
    try %#ok<TRYNC>
        delete(otf.(otf.figName).sphe);
        delete(otf.(otf.figName).ball);
    end
    
    tolSmall = 1;
    tolLarge = 3;
    
    if abs(rolDiff) > toleranceOrient(1,tolLarge)                % roll color
        colorRol = red;
    elseif abs(rolDiff) > toleranceOrient(1,tolSmall)
        colorRol = yellow;
    else
        colorRol = green;
    end
    
    if abs(pitDiff) > toleranceOrient(2,tolLarge)                % pitch color
        colorPit = red;
    elseif abs(pitDiff) > toleranceOrient(1,tolSmall)
        colorPit = yellow;
    else
        colorPit = green;
    end
    
    if abs(yawDiff) > toleranceOrient(3,tolLarge)                % yaw color
        colorYaw = red;
    elseif abs(yawDiff) > toleranceOrient(1,tolSmall)
        colorYaw = yellow;
    else
        colorYaw = green;
    end
    
    nexttile(oriTile, oriGrid)                                  % black sphere
    otf.(otf.figName).sphe = surf(x_sphere*r_sphe,y_sphere*r_sphe,z_sphere*r_sphe);
    otf.(otf.figName).ball = surf(x_sphere*r_ball+1.4,y_sphere*r_ball,z_sphere*r_ball);
    set(otf.(otf.figName).sphe, 'EdgeColor', grey, 'FaceColor', black, 'LineWidth', 10);
    set(otf.(otf.figName).ball, 'FaceAlpha', 1, 'FaceColor', 'cyan', 'LineStyle', 'none');
    rotate(otf.(otf.figName).sphe,[0 1 0],amp*pitDiff);
    rotate(otf.(otf.figName).sphe,[1 0 0],-amp*rolDiff);
    rotate(otf.(otf.figName).sphe,[0 0 1],-amp*yawDiff);
    rotate(otf.(otf.figName).ball,[0 1 0],amp*pitDiff);
    rotate(otf.(otf.figName).ball,[1 0 0],-amp*rolDiff);
    rotate(otf.(otf.figName).ball,[0 0 1],-amp*yawDiff);
    set(otf.(otf.figName).cir2, 'Facecolor', colorRol, 'EdgeColor', colorRol);
    set(otf.(otf.figName).cir3, 'Facecolor', colorPit, 'EdgeColor', colorPit);
    set(otf.(otf.figName).cir1, 'Facecolor', colorYaw, 'EdgeColor', colorYaw);
    set(otf.(otf.figName).trol, 'Color', colorRol);
    set(otf.(otf.figName).tpit, 'Color', colorPit);
    set(otf.(otf.figName).tyaw, 'Color', colorYaw);
    
    nexttile(7)                                                 % strafe icon
    set(otf.(otf.figName).stng, 'Visible','off');
    set(otf.(otf.figName).strr, 'Visible','off');
    set(otf.(otf.figName).stlr, 'Visible','off');
    set(otf.(otf.figName).stry, 'Visible','off');
    set(otf.(otf.figName).stly, 'Visible','off');
    if abs(xDiff) > tolerancePos(1,tolLarge)                    % strafe red
        if sign(xDiff) > 0
            set(otf.(otf.figName).stlr, 'Visible','on');
            strafe = 'left';
        else
            set(otf.(otf.figName).strr, 'Visible','on');
            strafe = 'right';
        end
        colorStrafe = red;
    elseif abs(xDiff) > tolerancePos(1,tolSmall)                % strafe yellow
        if sign(xDiff) > 0
            set(otf.(otf.figName).stly, 'Visible','on');
            strafe = 'left';
        else
            set(otf.(otf.figName).stry, 'Visible','on');
            strafe = 'right';
        end
        colorStrafe = yellow;
    else
        set(otf.(otf.figName).stng, 'Visible','on');
        strafe = 'left-right';
        colorStrafe = green;
    end
    otf.(otf.figName).nstr.XLabel.String = {strafe, append(num2str(floor(xDiff*10)), unit)};
    otf.(otf.figName).nstr.XLabel.Color = colorStrafe;
    
    nexttile(8)                                                 % elevate icon
    set(otf.(otf.figName).elng, 'Visible','off');
    set(otf.(otf.figName).elur, 'Visible','off');
    set(otf.(otf.figName).eldr, 'Visible','off');
    set(otf.(otf.figName).eluy, 'Visible','off');
    set(otf.(otf.figName).eldy, 'Visible','off');
    if abs(yDiff) > tolerancePos(2,tolLarge)                    % elevate red
        if sign(yDiff) > 0
            set(otf.(otf.figName).eldr, 'Visible','on');
            elevate = 'down';
        else
            set(otf.(otf.figName).elur, 'Visible','on');
            elevate = 'up';
        end
        colorElevate = red;
    elseif abs(yDiff) > tolerancePos(2,tolSmall)                % elevate yellow
        if sign(yDiff) > 0
            set(otf.(otf.figName).eldy, 'Visible','on');
            elevate = 'down';
        else
            set(otf.(otf.figName).eluy, 'Visible','on');
            elevate = 'up';
        end
        colorElevate = yellow;
    else
        set(otf.(otf.figName).elng, 'Visible','on');
        elevate = 'up-down';
        colorElevate = green;
    end
    otf.(otf.figName).nele.XLabel.String = {elevate, append(num2str(floor(yDiff*10)), unit)};
    otf.(otf.figName).nele.XLabel.Color = colorElevate;
    
    nexttile(9)                                                % surge icon
    set(otf.(otf.figName).sung, 'Visible','off');
    set(otf.(otf.figName).subr, 'Visible','off');
    set(otf.(otf.figName).sufr, 'Visible','off');
    set(otf.(otf.figName).suby, 'Visible','off');
    set(otf.(otf.figName).sufy, 'Visible','off');
    if abs(zDiff) > tolerancePos(3,tolLarge)                    % surge red
        if sign(zDiff) > 0
            set(otf.(otf.figName).sufr, 'Visible','on');
            surge = 'front';
        else
            set(otf.(otf.figName).subr, 'Visible','on');
            surge = 'back';
        end
        colorSurge = red;
    elseif abs(zDiff) > tolerancePos(3,tolSmall)                % surge yellow
        if sign(zDiff) > 0
            set(otf.(otf.figName).sufy, 'Visible','on');
            surge = 'front';
        else
            set(otf.(otf.figName).suby, 'Visible','on');
            surge = 'back';
        end
        colorSurge = yellow;
    else
        set(otf.(otf.figName).sung, 'Visible','on');
        surge = 'front-back';
        colorSurge = green;
    end
    otf.(otf.figName).nsur.XLabel.String = {surge, append(num2str(floor(zDiff*10)), unit)};
    otf.(otf.figName).nsur.XLabel.Color = colorSurge;
    
end

end

function generate_figure_properties(ot) %#ok

varName = ['sphe'; 'ball'; 'cir1'; 'cir2'; 'cir3'; ...  % sphere icon
    'stng'; 'strr'; 'stlr'; 'stry'; 'stly'; ...     % surge icon
    'elng'; 'elur'; 'eldr'; 'eluy'; 'eldy'; ...     % elevate icon
    'sung'; 'subr'; 'sufr'; 'suby'; 'sufy'; ...     % surge icon
    'trol'; 'tpit'; 'tyaw'; ...                     % orientaiton text
    'nstr'; 'nele'; 'nsur'];                        % tiles
for index = 1 : size(varName,1)
    eval('if ~isprop(ot.(ot.figName), varName(index,:)) addprop(ot.(ot.figName), varName(index,:)); end')
end

end
