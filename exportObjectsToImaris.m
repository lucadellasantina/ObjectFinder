%% Pass objects detected by the ObjectFinder to Imaris version 7.2.3
%
% send dots found with dotfinder to Imaris
% imaris spots will be displayed as passing and nonpassing dots. 
% can also choose the statistics (dot properties) sent into imaris for both
% passing and non passing dots
% -------------------------------------------------------------------------
% Version 2.0                                2017-08-03 Luca Della Santina
%
% + Automatically detect and load saved imaris scene
% + Allow loading of SG.PassF or SG.PassI or All objects
% + Encapsulated the current code into a function
% % Made compatible with Imaris 7.2.3
%
% Version 1.0                                2010-01-08 Adam Bleckert
% -------------------------------------------------------------------------
function[] = exportObjectsToImaris(Settings, Dots, SG)

% Start Imaris using COM interface
vImarisApplication = actxserver('Imaris.Application');
vImarisApplication.mVisible = true;
pause(2) % imaris startup is slow sometimes,, and calling a file will cause a crash if imaris isnt running

% Load the imaris file contained in the TPN/I folder 
TPN = Settings.TPN;
if isempty(vImarisApplication.GetCurrentFileName)
    tmpDir=[TPN 'I' filesep];
    tmpFile = dir([tmpDir '*.ims']);
    vImarisApplication.FileOpen([tmpDir tmpFile(1).name], 'LoadDataSet="eDataSetYes"');
end

%% Aquire Matlab Dot information  
xyum = Settings.ImInfo.xyum; 
zum = Settings.ImInfo.zum;

% get the passing IDS
Iprompt = {'SG.passF:','SG.passI:','All objects'};
Inum_lines = 1;
if isfield(SG, 'passI')
    Idef = {'0','1','0'};
else
    Idef = {'1','0','0'};
end
Answer = inputdlg(Iprompt,'Select objects to transfer',Inum_lines ,Idef);
if isempty(Answer), return, end

if str2double(cell2mat(Answer(1)))==1
    passingIDs = SG.passF';
elseif str2double(cell2mat(Answer(2)))==1
    passingIDs = SG.passI';
else
    passingIDs = ones(1, Dots.Num);
end

% Changing passingIDs from passF/passI form (0 or 1 in each element) 
% to list of dot IDs (1 to total number of dots, as expected by Imaris)
PassDotIDs = find(passingIDs==1);
NoPassDotIDs = find(passingIDs==0);

dPosPassF = Dots.Pos(PassDotIDs,:); %(dotPassingID,:); % create directory of passing dots positions
dPosPassF(:,1:2)=(dPosPassF(:,1:2)-0.5)*xyum; %convert dots into actual values(um)
dPosPassF(:,3)=(dPosPassF(:,3)-0.5)*zum;
SPosPassF=[dPosPassF(:,2),dPosPassF(:,1),dPosPassF(:,3)]; % transpose x and y to convert from Matlab to Imaris
xyzVolConv = xyum^2*zum;
dVolpassF = Dots.Vol(PassDotIDs).*xyzVolConv;
dRadiusPassF = (dVolpassF.*3/(4*pi)).^(1/3);

dPosNoPassF = Dots.Pos(NoPassDotIDs,:); %(dotPassingID,:); % create directory of passing dots positions
dPosNoPassF(:,1:2)=dPosNoPassF(:,1:2)*xyum; %convert dots into actual values(um)
dPosNoPassF(:,3)=dPosNoPassF(:,3)*zum;
SPosNoPassF=[dPosNoPassF(:,2),dPosNoPassF(:,1),dPosNoPassF(:,3)]; % transpose x and y to convert from Matlab to Imaris
xyzVolConv = xyum^2*zum;
dVolNopassF = Dots.Vol(NoPassDotIDs).*xyzVolConv;
dRadiusNoPassF = (dVolNopassF.*3/(4*pi)).^(1/3); 


%% create spots from matlab data
% gather passing dots
vSpotsAPosXYZ = SPosPassF;
vSpotsARadius = dRadiusPassF;
vSpotsAPosT = zeros(1,length(dPosPassF));
% gather non passing dots
vSpotsBPosXYZ = SPosNoPassF;
vSpotsBRadius = dRadiusNoPassF;
vSpotsBPosT = zeros(1,length(dPosNoPassF));

% add passing spots to Imaris
vSpotsA = vImarisApplication.mFactory.CreateSpots;
vSpotsA.Set(vSpotsAPosXYZ, vSpotsAPosT, vSpotsARadius);
vSpotsA.mName = sprintf('passing');
vSpotsA.SetColor(0.0, 1.0, 0.0, 0.0);
vImarisApplication.mSurpassScene.AddChild(vSpotsA);

% add non passing spots to Imaris
vSpotsB = vImarisApplication.mFactory.CreateSpots;
vSpotsB.Set(vSpotsBPosXYZ, vSpotsBPosT, vSpotsBRadius);
vSpotsB.mName = sprintf('nonpassing');
vSpotsB.SetColor(0.0, 0.0, 1.0, 0.0);
vImarisApplication.mSurpassScene.AddChild(vSpotsB);
vSpotsB.mVisible = 0;

%% get spots statistics and push them into Imaris
[aNames,aValues,aUnits,aFactors,aFactorNames,aIds]=vSpotsA.GetStatistics;
clear aNames; clear aValues; clear aUnits; clear aFactors; clear aIds;

dotFN = fieldnames(Dots);
[vDotsStats,vOk] = listdlg('ListString', dotFN,...
        'SelectionMode','multiple', ...
        'ListSize',[300 300], 'Name','DotsStats', ...
        'PromptString',{'Please select passing dot stats:'});
        if vOk<1, return, end
dotStatsNames = dotFN(vDotsStats);

for i = 1:length(dotStatsNames)
    for j = 1:length(vSpotsAPosXYZ)
        aNames{j,1} = strcat('RC_' ,dotStatsNames{i});
        aValues(j,1) = single(Dots.(dotStatsNames{i})(PassDotIDs(j)));
        aUnits{j,1} = 'arb';
        aFactors{1,j} = 'Spots';
        aFactors{2,j} = '';
        aFactors{3,j} = '1';
        aIds(j,1) = int32(j-1);
    end
    vSpotsA.AddStatistics(aNames,aValues,aUnits,aFactors,aFactorNames,aIds);
    clear aNames; clear aValues; clear aUnits; clear aFactors; clear aIds;
end
input('Press Enter when done using Imaris');

end