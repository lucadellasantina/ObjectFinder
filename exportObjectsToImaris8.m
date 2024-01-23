%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2024 Luca Della Santina
%
%  This file is part of ObjectFinder
%
%  ObjectFinder is free software: you can redistribute it and/or modify
%  it under the terms of the GNU General Public License as published by
%  the Free Software Foundation, either version 3 of the License, or
%  (at your option) any later version.
%
%  This program is distributed in the hope that it will be useful,
%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%  GNU General Public License for more details.
%
%  You should have received a copy of the GNU General Public License
%  along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
% *Pass objects detected by the ObjectFinder to Imaris version 8 and newer
function exportObjectsToImaris8(Dots)
try
    javaaddpath(which('ImarisLib.jar'));
catch
    disp('Error: ImarisLib.jar is not in your matlab path, please add path to this file, it located in your Imaris install forlder/XT/matlab/');
end

vImarisLib = ImarisLib;

try
    vServer = vImarisLib.GetServer;
    vImaris = vImarisLib.GetApplication(vServer.GetObjectID(0));
    vImaris.SetVisible(true);
catch
    disp('Error: Imaris is not running, please start imaris and then try again.');
    return
end
%% Load the imaris file contained in the I folder 
if strcmp(vImaris.GetCurrentFileName,'')
    tmpDir  = [pwd filesep 'I' filesep];
    tmpFile = dir([tmpDir '*.ims']);
    vImaris.FileOpen([tmpDir tmpFile(1).name], '');
end

%% Aquire Matlab Dot information  
xyum                = Dots.Settings.ImInfo.xyum;    % image calibration
zum                 = Dots.Settings.ImInfo.zum;     % image calibration
passingIDs          = Dots.Filter.passF';           % Passing objects' IDs

% Changing passingIDs from passF/passI form (0 or 1 in each element) 
% to list of dot IDs (1 to total number of dots, as expected by Imaris)
PassDotIDs          = find(passingIDs==1);
NoPassDotIDs        = find(passingIDs==0);

% Default to show only objects passing the Filter conditions
Dots.Settings.Inspect3D.showPassing      = 1;
Dots.Settings.Inspect3D.showNonPassing   = 0;

% Process passing objects
if Dots.Settings.Inspect3D.showPassing
    dPosPassF       = Dots.Pos(PassDotIDs,:);       %(dotPassingID,:); % create directory of passing dots positions
    dPosPassF(:,1:2)= (dPosPassF(:,1:2)-0.5)*xyum;  % Pixel positions into calibrated values(um)
    dPosPassF(:,3)  = (dPosPassF(:,3)-0.5)*zum;
    SPosPassF       = [dPosPassF(:,2),dPosPassF(:,1),dPosPassF(:,3)]; % transpose x and y to convert from Matlab to Imaris
    xyzVolConv      = xyum^2*zum;
    dVolpassF       = Dots.Vol(PassDotIDs).*xyzVolConv;
    dRadiusPassF    = (dVolpassF.*3/(4*pi)).^(1/3);

    % convert passing objects to imaris spots format
    vSpotsAPosXYZ   = SPosPassF;
    vSpotsARadius   = dRadiusPassF;
    vSpotsAPosT     = zeros(1,length(dPosPassF));

    % Add passing objects to Imaris as a set of spots
    vSpotsA         = vImaris.GetFactory.CreateSpots;
    vSpotsA.Set(vSpotsAPosXYZ, vSpotsAPosT, vSpotsARadius);
    vSpotsA.SetName('passing');
    vRGBA = [0.0, 1.0, 0.0, 0.0];
    vRGBA = round(vRGBA * 255); % need integer values scaled to range 0-255
    vRGBA = uint32(vRGBA * [1; 256; 256*256; 256*256*256]); % combine different components (four bytes) into one integer
    vSpotsA.SetColorRGBA(vRGBA);    
    vImaris.GetSurpassScene.AddChild(vSpotsA, -1);
    pause(1); % This pause is needed to allow Imaris time to load scene

    % Import custom spots statistics into Imaris
    try
        vStatistics = vSpotsA.GetStatistics;
        aNames = cell(vStatistics.mNames);
        aValues = vStatistics.mValues;
        aUnits = cell(vStatistics.mUnits);
        aFactors = cell(vStatistics.mFactors);
        aFactorNames = cell(vStatistics.mFactorNames);
        aIds = vStatistics.mIds;
        
        % Add ITmax as score parameter
        for j = 1:length(vSpotsAPosXYZ)
            aNames{j,1}     = strcat('ObjectFinder_Score');
            aValues(j,1)    = single(Dots.ITMax(PassDotIDs(j)));
            aUnits{j,1}     = 'arb';
            aIds(j,1)       = int32(j-1);
        end
        vSpotsA.AddStatistics(aNames,aValues,aUnits,aFactors,aFactorNames,aIds);
        
        % Add volume parameter from Dots.Vol
        for j = 1:length(vSpotsAPosXYZ)
            aNames{j,1}     = strcat('ObjectFinder_Volume');
            aValues(j,1)    = single(Dots.Vol(PassDotIDs(j)));
        end
        vSpotsA.AddStatistics(aNames,aValues,aUnits,aFactors,aFactorNames,aIds);

        % Add Brightness parameter from Dots.MeanBright
        for j = 1:length(vSpotsAPosXYZ)
            aNames{j,1}     = strcat('ObjectFinder_Brightness');
            aValues(j,1)    = single(Dots.MeanBright(PassDotIDs(j)));
        end
        vSpotsA.AddStatistics(aNames,aValues,aUnits,aFactors,aFactorNames,aIds);

        if isfield(Dots.Shape,'Oblong')
            for j = 1:length(vSpotsAPosXYZ)
                aNames{j,1}     = strcat('ObjectFinder_Oblongness');
                aValues(j,1)    = single(Dots.Shape.Oblong(PassDotIDs(j)));
            end
            vSpotsA.AddStatistics(aNames,aValues,aUnits,aFactors,aFactorNames,aIds);
        end
        
        if isfield(Dots.Shape,'PrincipalAxisLen')
            for j = 1:length(vSpotsAPosXYZ)
                aNames{j,1}     = strcat('ObjectFinder_PrincipalAxisLen');
                aValues(j,1)    = single(Dots.Shape.PrincipalAxisLen(PassDotIDs(j)));
            end
            vSpotsA.AddStatistics(aNames,aValues,aUnits,aFactors,aFactorNames,aIds);
        end        
    catch
        disp('Error pushing custom statistics into Imaris');
        return
    end
end

%% Wait for user input to close and catch validated objects
disp('Select valid objects as spots in Imaris, then press Enter in matlab command window when done');
input('Press Enter when done using Imaris');

%% Now catch the imaris-validated spots and export back to MATLAB

vSurpassScene = vImaris.GetSurpassScene();
if isequal(vSurpassScene, [])
    msgbox('Please create a Surpass scene!');
    return;
end

% make directory of Spots in surpass scene
cnt = 0;
for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
    if vImaris.GetFactory.IsSpots(vSurpassScene.GetChild(vChildIndex - 1))
        cnt = cnt+1;
        vSpots{cnt} = vImaris.GetFactory.ToSpots(vSurpassScene.GetChild(vChildIndex - 1));
    end
end

% Choose passing spots
vSpotsCnt = length(vSpots);
for n= 1:vSpotsCnt
    vSpotsName{n} = vSpots{n}.GetName;
end
cellstr = cell2struct(vSpotsName,{'names'},vSpotsCnt+2);
str = string({cellstr.names});
[vAnswer_iPass,~] = listdlg('ListSize',[200 160], 'PromptString','Validated spots to export back to ObjectFinder', 'SelectionMode','single', 'ListString',str);

if ~isempty(vAnswer_iPass)
    iPassSpots          = vSpots{vAnswer_iPass};
    vYesSpotsXYZ        = iPassSpots.GetPositionsXYZ;
    vYesSpotsXYZ        = double(vYesSpotsXYZ);% has to be double because 2048*2048*69 is larger than 2^24 ( the real limit of single precision... the output of imaris (see:http://stackoverflow.com/questions/4513346/convert-double-to-single-without-loss-of-precision-in-matlab))
    
    % Find the passing Dots identities
    %iPassSpotsXYZ      = [ceil(vYesSpotsXYZ(:,2)./xyum),ceil(vYesSpotsXYZ(:,1)./xyum),ceil(vYesSpotsXYZ(:,3)./zum)];%swap x and y for matlab conversion and convert to matrix values %HO changed round to ceil 6/16/2011.
    iPassSpotsXYZ       = [ceil(vYesSpotsXYZ(:,1)./xyum),ceil(vYesSpotsXYZ(:,2)./xyum),ceil(vYesSpotsXYZ(:,3)./zum)];%x y looks fine for me. HO 6/16/2011.
    iPassSpotsXYZ(iPassSpotsXYZ<1) = 1; % boarder gaurd for rounding conversion errors (matrix ind cannot be 0 or greater than Dots.ImSize(1,2))
    iPassSpotsX         = iPassSpotsXYZ(:,1);
    iPassSpotsY         = iPassSpotsXYZ(:,2);
    iPassSpotsZ         = iPassSpotsXYZ(:,3);
    iPassSpotsX(iPassSpotsX>max(Dots.ImSize(2))) = max(Dots.ImSize(2)); % border guard for max X.
    iPassSpotsY(iPassSpotsY>max(Dots.ImSize(1))) = max(Dots.ImSize(1)); % border guard for max Y.
    iPassSpotsZ(iPassSpotsZ>max(Dots.ImSize(3))) = max(Dots.ImSize(3)); % border guard for max Z.
    iPassSpotsXYZ       = [iPassSpotsX iPassSpotsY iPassSpotsZ];
    clear iPassSpotsX iPassSpotsY iPassSpotsZ;
    iPassSpotsXYZ       = double(iPassSpotsXYZ);
    %iPassSpotsInd      = sub2ind([Dots.ImSize], iPassSpotsXYZ(:,1),iPassSpotsXYZ(:,2),iPassSpotsXYZ(:,3));
    iPassSpotsInd       = sub2ind([Dots.ImSize], iPassSpotsXYZ(:,2),iPassSpotsXYZ(:,1),iPassSpotsXYZ(:,3)); %Now use YXZ (row, column, z) format to convert to index HO 6/16/2011
    DotsVoxIDMap        = zeros(Dots.ImSize); % create matrix with ID of dot assigned to each voxel of dot
    for i=1:Dots.Num
        DotsVoxIDMap(Dots.Vox(i).Ind) = i;
    end
    
    DotsfoundID         = DotsVoxIDMap(iPassSpotsInd);
    DotsmissedID        = find(DotsfoundID==0); % get index of missed IDs to search for positions
    for j = 1:length(DotsmissedID) %find the closest dot to the missing dots
        for k = Dots.Num:-1:1
            xyDistUm    = hypot(vYesSpotsXYZ(DotsmissedID(j),2)-Dots.Pos(k,1).*xyum,vYesSpotsXYZ(DotsmissedID(j),1)-Dots.Pos(k,2).*xyum); %vYesSpotsXYZ from imaris is transposed over the xy axis so Dots and vYes.. have switched XY
            xyzDistUm(k)= hypot(xyDistUm, vYesSpotsXYZ(DotsmissedID(j),3)-Dots.Pos(k,3).*zum);
        end
        minDistUm       = find(xyzDistUm==min(xyzDistUm));
        
        %Luca: added additional check for newly created dots,
        %      they must be assigned to a existing dot only if that is
        %      closer than 1 micron to the position specified in Imaris
        if minDistUm > 4
            fprintf('Imaris spot has no objet closer than 4um\n');
            DotsfoundID(DotsmissedID(j)) = -1;
        else
            DotsfoundID(DotsmissedID(j)) = minDistUm;
        end
    end
    
    DotsfoundID = DotsfoundID(DotsfoundID >= 0); % Exclude Imaris dots that found no matching in matlab dots
    Hit3D       = unique(DotsfoundID);
    
    Filter.passF        = false(Dots.Num,1); % Store passing spots
    Filter.passF(Hit3D) = true;
    save([pwd filesep 'Filter.mat'], 'Filter'); 

    disp('Passing spots exported successfully!');
else
    disp('Exporting operation of Imaris-validated objects was cancelled by user');
end
end