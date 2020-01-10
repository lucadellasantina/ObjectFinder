%% Instructions
%
%  Send Imaris selected spots to Matlab
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Spots Functions">
%        <Item name="ObjectFinder Export Passing Spots To MATLAB" icon="Matlab" tooltip="PassingSpots2ML">
%          <Command>Matlab::ObjectFinderPassingSpotsToMATLAB(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="ObjectFinder Export Passing Spots To MATLAB" icon="Matlab" tooltip="iPassingSpots2MLDotsVer. -HO">
%            <Command>Matlab::ObjectFinderPassingSpotsToMATLAB(%i)</Command>
%          </Item>
%        </SurpassComponent>
%        <SurpassComponent name="bpSpots">
%          <Item name="ObjectFinder Export Passing Spots To MATLAB" icon="Matlab" tooltip="iPassingSpots2MLDotsVer. -HO">
%            <Command>Matlab::ObjectFinderPassingSpotsToMATLAB(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
%
%  
%  Description:
%
%   The User has to choose final spots from matlab dots mapped into
%   imaris to send back to matlab
%

%% Connect to Imaris Com interface
function ObjectFinderPassingSpotsToMATLAB(aImarisApplicationID)

if ~isa(aImarisApplicationID, 'COM.Imaris_Application')
    vImarisServer = actxserver('ImarisServer.Server');
    vImarisApplication = vImarisServer.GetObject(aImarisApplicationID);
else
    vImarisApplication = aImarisApplicationID;
end

%% Start Imaris from matlab and make it visible (comment before saving)
%   vImarisApplication=actxserver('Imaris.Application');
%    vImarisApplication.mVisible=true;

%% the user has to create a scene
vSurpassScene = vImarisApplication.mSurpassScene;
if isequal(vSurpassScene, [])
    msgbox('Please create a Surpass scene!');
    return;
end

%% make directory of Spots in surpass scene
cnt = 0;
for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
    if vImarisApplication.mFactory.IsSpots(vSurpassScene.GetChild(vChildIndex - 1))
        cnt = cnt + 1;
        vSpots{cnt} = vSurpassScene.GetChild(vChildIndex - 1); %#ok
    end
end

%% choose passing spots
vSpotsCnt = length(vSpots);
for n= vSpotsCnt:-1:1
    vSpotsName{n} = vSpots{n}.mName;
end
cellstr = cell2struct(vSpotsName,{'names'},vSpotsCnt+2);
str = {cellstr.names};
[vAnswer_iPass,~] = listdlg('ListSize',[200 160], ...
    'PromptString','Choose "final" spots:',...
    'SelectionMode','single',...
    'ListString',str);

iPassSpots = vSpots{vAnswer_iPass};
[vYesSpotsXYZ,~,~] = iPassSpots.Get;
vYesSpotsXYZ = double(vYesSpotsXYZ);% has to be double because 2048*2048*69 is larger than 2^24 ( the real limit of single precision... the output of imaris (see:http://stackoverflow.com/questions/4513346/convert-double-to-single-without-loss-of-precision-in-matlab))

%% load directory of passing spots
TPN = uigetdir;
TPN = [TPN filesep];
load([TPN 'Dots.mat'], 'Dots');
load([TPN 'Filter.mat'], 'Filter');
load([TPN 'Settings.mat'], 'Settings');
xyum = Settings.ImInfo.xyum;
zum = Settings.ImInfo.zum;

%% find the passing Dots identities
%iPassSpotsXYZ = [ceil(vYesSpotsXYZ(:,2)./xyum),ceil(vYesSpotsXYZ(:,1)./xyum),ceil(vYesSpotsXYZ(:,3)./zum)];%swap x and y for matlab conversion and convert to matrix values %HO changed round to ceil 6/16/2011.
iPassSpotsXYZ = [ceil(vYesSpotsXYZ(:,1)./xyum),ceil(vYesSpotsXYZ(:,2)./xyum),ceil(vYesSpotsXYZ(:,3)./zum)];%x y looks fine for me. HO 6/16/2011.
iPassSpotsXYZ(iPassSpotsXYZ<1) = 1; % boarder gaurd for rounding conversion errors (matrix ind cannot be 0 or greater than Dots.ImSize(1,2))
iPassSpotsX = iPassSpotsXYZ(:,1);
iPassSpotsY = iPassSpotsXYZ(:,2);
iPassSpotsZ = iPassSpotsXYZ(:,3);
iPassSpotsX(iPassSpotsX>max(Dots.ImSize(2))) = max(Dots.ImSize(2)); % boarder gaurd for max X.
iPassSpotsY(iPassSpotsY>max(Dots.ImSize(1))) = max(Dots.ImSize(1)); % boarder gaurd for max Y.
iPassSpotsZ(iPassSpotsZ>max(Dots.ImSize(3))) = max(Dots.ImSize(3)); % boarder gaurd for max Z.
iPassSpotsXYZ = [iPassSpotsX iPassSpotsY iPassSpotsZ];
clear iPassSpotsX iPassSpotsY iPassSpotsZ;
iPassSpotsXYZ = double(iPassSpotsXYZ);
%iPassSpotsInd = sub2ind([Dots.ImSize], iPassSpotsXYZ(:,1),iPassSpotsXYZ(:,2),iPassSpotsXYZ(:,3));
iPassSpotsInd = sub2ind([Dots.ImSize], iPassSpotsXYZ(:,2),iPassSpotsXYZ(:,1),iPassSpotsXYZ(:,3)); %Now use YXZ (row, column, z) format to convert to index HO 6/16/2011
DotsVoxIDMap = zeros(Dots.ImSize); % create matrix with ID of dot assigned to each voxel of dot
for i=1:Dots.Num
    DotsVoxIDMap(Dots.Vox(i).Ind)=i;
end

DotsfoundID = DotsVoxIDMap(iPassSpotsInd);
DotsmissedID = find(DotsfoundID==0); % get index of missed IDs to search for positions
for j = 1:length(DotsmissedID) %find the closest dot to the missing dots
    for k = Dots.Num:-1:1
        xyDistUm = hypot(vYesSpotsXYZ(DotsmissedID(j),2)-Dots.Pos(k,1).*xyum,vYesSpotsXYZ(DotsmissedID(j),1)-Dots.Pos(k,2).*xyum); %vYesSpotsXYZ from imaris is transposed over the xy axis so Dots and vYes.. have switched XY
        xyzDistUm(k) = hypot(xyDistUm, vYesSpotsXYZ(DotsmissedID(j),3)-Dots.Pos(k,3).*zum);
    end
    minDistUm = find(xyzDistUm==min(xyzDistUm));
    
    %Luca: added additional check for newly created dots,
    %      they must be assigned to a existing dot only if that is
    %      closer than 1 micron to the position specified in Imaris
    if minDistUm > 4
        fprintf('Imaris spot with no dot closer than 4um found.\n');
        DotsfoundID(DotsmissedID(j)) = -1;
    else
        DotsfoundID(DotsmissedID(j)) = minDistUm;
    end
end

DotsfoundID = DotsfoundID(DotsfoundID>=0); %Luca: Exclude Imaris dots that found no matching in matlab dots
Hit3D = unique(DotsfoundID);

Filter.passF = false(Dots.Num,1);% setup SG.passI variable (Imaris passing)
Filter.passF(Hit3D) = true;
save([TPN 'Filter.mat'],'Filter');
disp('Passing spots exported successfully!');
end
