%% RAVEN simulation: Example to use new experimental binary of RAVEN

% Author: las@akustik.rwth-aachen.de
% date:     2025/01/16
%
% <ITA-Toolbox>
% This file is part of the application Raven for the ITA-Toolbox. All rights reserved.
% You can find the license for this m-file in the application folder.
% </ITA-Toolbox>

%% project settings
% easy way, simply load a project file using the default project
ravenBasePath='C:\ITASoftware\Raven\';
rpf = itaRavenProject([ ravenBasePath 'RavenProjects\TestShoeboxRoom\TestShoeboxRoomLAS.rpf']);

% set RavenConsole binary to most recent version
rpf.setRavenExe([ ravenBasePath 'bin64_2024a\RavenConsole.exe']);

% create individual demo file name
rpf.copyProjectToNewRPFFile([ ravenBasePath '\RavenProjects\TestShoeboxRoom\TestShoeboxRoom_Demo.rpf' ]);
rpf.setProjectName('TestShoeboxRoom_Demo2024a');

%% set Directivity data for source and receiver
% the 2024a version of RavenConsole only supports DAFFv17 data for source
% and receiver characteristics. If not available, data needs be converted
pathHRTFv15 = [ ravenBasePath 'RavenDatabase\HRTF\ITA-Kunstkopf_HRIR_AP11_Pressure_Equalized_3x3_256.daff'];
pathHRTFv17 = [ ravenBasePath 'RavenDatabase\HRTF\ITA-Kunstkopf_HRIR_AP11_Pressure_Equalized_3x3_256.v17.daff'];
daffv17_convert_from_daffv15(pathHRTFv15,pathHRTFv17);
rpf.setReceiverHRTF(pathHRTFv17);

pathSourceDirectivity_v15 = [ ravenBasePath 'RavenDatabase\DirectivityDatabase\Loudspeaker_KHO100_5x5.daff'];
pathSourceDirectivity_v17 = [ ravenBasePath 'RavenDatabase\DirectivityDatabase\Loudspeaker_KHO100_5x5.v17.daff'];
daffv17_convert_from_daffv15(pathSourceDirectivity_v15,pathSourceDirectivity_v17);
rpf.setSourceDirectivity(pathSourceDirectivity_v17);


%% run simulation and get results
rpf.run
BRIR = rpf.getBinauralImpulseResponseItaAudio;

