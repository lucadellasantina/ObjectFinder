%% Instructions
%
%  Filter volume channel with filament mask
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Filament Functions">
%        <Item name="ObjectFinder Save filament as mask image (multiple skeletons)" icon="Matlab" tooltip="Save filament as mask image.">
%          <Command>Matlab::ObjectFinderSaveFilamentAsMaskNoSoma(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpFilament">
%          <Item name="ObjectFinder Save filament as mask image (multiple skeletons)" icon="Matlab" tooltip="Save filament as mask image.">
%            <Command>Matlab::ObjectFinderSaveFilamentAsMaskNoSoma(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
%
%
%  Description:
%
%   The User has to have a filament. The filament nodes will be used to
%   create a mask of [*] microns in diameter in order to selectively crop
%   a volume channel.
%
%

%% Use Filament to make mask
function ObjectFinderSaveFilamentAsMaskNoSoma(aImarisApplicationID)

if isa(aImarisApplicationID, 'COM.Imaris_Application')
    vImarisApplication = aImarisApplicationID;
else
    % connect to Imaris Com interface
    vImarisServer = actxserver('ImarisServer.Server');
    vImarisApplication = vImarisServer.GetObject(aImarisApplicationID);
end

%% if testing from matlab (comment out before saving)

%     vImarisApplication = actxserver('Imaris.Application');
%     vImarisApplication.mVisible = true;

%% find the surpass scene

% the user has to create a scene with a filament
vSurpassScene = vImarisApplication.mSurpassScene;
if isequal(vSurpassScene, [])
    msgbox('Please create Surpass scene!')
    return
end

%% make directory of filaments in surpass scene
cnt = 0;
for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
    if vImarisApplication.mFactory.IsFilament(vSurpassScene.GetChild(vChildIndex - 1))
        cnt = cnt+1;
        vFilaments{cnt} = vSurpassScene.GetChild(vChildIndex - 1);
    end
end

%% choose the correct Filament
vFilamentsCnt = length(vFilaments);
for n= 1:vFilamentsCnt
    vFilamentsName{n} = vFilaments{n}.mName;
end
cellstr = cell2struct(vFilamentsName,{'names'},vFilamentsCnt+2);
str = {cellstr.names};

if vFilamentsCnt == 1
    vFilament = vFilaments{1};
else
    [vAnswer_yes,~] = listdlg('ListSize',[200 160], 'PromptString','Choose Filament:', 'SelectionMode','single','ListString',str);
    vFilament = vFilaments{vAnswer_yes};
end

%% get the dataset dimensions
vSizeX=vImarisApplication.mDataSet.mSizeX;
vSizeY=vImarisApplication.mDataSet.mSizeY;
vSizeZ=vImarisApplication.mDataSet.mSizeZ;
vSizeC=vImarisApplication.mDataSet.mSizeC; % 20101106 AB added getting channel info
vSizeT = vImarisApplication.mDataSet.mSizeT;% 20101106 AB added getting time info

xyum = (vImarisApplication.mDataSet.mExtendMaxX-vImarisApplication.mDataSet.mExtendMinX)/vSizeX;
zum = (vImarisApplication.mDataSet.mExtendMaxZ-vImarisApplication.mDataSet.mExtendMinZ)/vSizeZ;

vDataSet = vImarisApplication.mDataSet;% 20101106 AB dont use clone it eats memory, just asign vDataSet to the current dataset
%% user input of channel for masking

vAnswer = inputdlg({'Extra XY radius (um):\n',...
                    'Extra Z radius (um)',...
                    'XY voxel size (um)', 'Z voxel size (um)'}, ...
                    'Choose Channel', 1, {'1','0.5', num2str(xyum), num2str(zum)});

if isempty(vAnswer)
    return
end

XYExtraRad          = str2double(vAnswer(1));
ZExtraRad           = str2double(vAnswer(2));
vVoxSizeXY          = str2double(vAnswer(3));
vVoxSizeZ           = str2double(vAnswer(4));

%% get filament positions parameters

vFilamentAPosXYZ    = vFilament.GetPositionsXYZ;
vFilamentARadius    = vFilament.GetRadii';
vFilamentAEdges     = vFilament.GetEdges;

%% create elipsoidal mask around filament

if strcmp(vDataSet.mType, 'eTypeUInt8') %better to use 8bit than 12bit because 12bit (using uint16) makes it too slow HO
    Filterchannel   = zeros(vSizeX, vSizeY, vSizeZ, 'uint8');
elseif strcmp(vDataSet.mType, 'eTypeUInt16') %this was eTypeInt16 instead of eTypeUInt16 thus generating error when used for 12-bit image 2/11/2010 HO
    Filterchannel   = zeros(vSizeX, vSizeY, vSizeZ, 'uint16');
elseif strcmp(vDataSet.mType, 'eTypeFloat')
    Filterchannel   = zeros(vSizeX, vSizeY, vSizeZ, 'single');
end
%flip x and y for meshgrid to adjust to Filterchannel
[meshY, meshX, meshZ] = meshgrid(single(vVoxSizeXY/2:vVoxSizeXY:vVoxSizeXY*vSizeY-vVoxSizeXY/2), single(vVoxSizeXY/2:vVoxSizeXY:vVoxSizeXY*vSizeX-vVoxSizeXY/2),single( vVoxSizeZ/2:vVoxSizeZ:vVoxSizeZ*vSizeZ-vVoxSizeZ/2));

for i=1:length(vFilamentARadius)
    if sqrt((vFilamentAPosXYZ(i,1)).^2 + (vFilamentAPosXYZ(i,2)).^2 + (vFilamentAPosXYZ(i,3)).^2) >= 0
        
        XYradius = vFilamentARadius(i)+XYExtraRad;
        Zradius = XYradius+ZExtraRad;
        ZRadOverXYRad = Zradius/XYradius;
        
        %Just one line below is good enough for spherical masking, but takes too
        %long time because it uses full size matrix for calculation per each iteration.
        %So, instead of using this one line, do the following lines which cut a piece
        %of matrix from the full size matrix and use this small matrix for calculation.
        %Filterchannel(sqrt((meshX-vFilamentAPosXYZ(i,1)).^2 + (meshY-vFilamentAPosXYZ(i,2)).^2 + (meshZ-vFilamentAPosXYZ(i,3)).^2) <= radius) = 1;
        
        subx = floor((vFilamentAPosXYZ(i,1)-XYradius)/vVoxSizeXY):ceil((vFilamentAPosXYZ(i,1)+XYradius)/vVoxSizeXY);
        suby = floor((vFilamentAPosXYZ(i,2)-XYradius)/vVoxSizeXY):ceil((vFilamentAPosXYZ(i,2)+XYradius)/vVoxSizeXY);
        subz = floor((vFilamentAPosXYZ(i,3)-Zradius)/vVoxSizeZ):ceil((vFilamentAPosXYZ(i,3)+Zradius)/vVoxSizeZ);
        subx(subx<1)=[];
        subx(subx>vSizeX)=[];
        suby(suby<1)=[];
        suby(suby>vSizeY)=[];
        subz(subz<1)=[];
        subz(subz>vSizeZ)=[];
        submeshX = meshX(subx, suby, subz);
        submeshY = meshY(subx, suby, subz);
        submeshZ = meshZ(subx, suby, subz);
        CenteredSubmeshX = submeshX-vFilamentAPosXYZ(i,1);
        CenteredSubmeshY = submeshY-vFilamentAPosXYZ(i,2);
        CenteredScaledSubmeshZ = (submeshZ-vFilamentAPosXYZ(i,3))/ZRadOverXYRad; %change the scale for z axis so that the following spherical masking actually generate elipsoidal mask. 1/5/2010
        
        sphr = sqrt(CenteredSubmeshX.^2 + CenteredSubmeshY.^2 + CenteredScaledSubmeshZ.^2) <= XYradius;
        if strcmp(vDataSet.mType, 'eTypeUInt8') %better to use 8bit than 12bit because 12bit (using uint16) makes it too slow HO
            Filterchannel(subx, suby, subz) = Filterchannel(subx, suby, subz) + uint8(sphr);
        elseif strcmp(vDataSet.mType, 'eTypeUInt16') %this was eTypeInt16 instead of eTypeUInt16 thus generating error when used for 12-bit image 2/11/2010 HO
            Filterchannel(subx, suby, subz) = Filterchannel(subx, suby, subz) + uint16(sphr);
        elseif strcmp(vDataSet.mType, 'eTypeFloat')
            Filterchannel(subx, suby, subz) = Filterchannel(subx, suby, subz) + single(sphr);
        end
    end
end
clear meshX; clear meshY; clear meshZ;

if strcmp(vDataSet.mType, 'eTypeUInt8') %better to use 8bit than 12bit because 12bit (using uint16) makes it too slow HO
    Filterchannel = uint8(Filterchannel>0);
elseif strcmp(vDataSet.mType, 'eTypeUInt16') %this was eTypeInt16 instead of eTypeUInt16 thus generating error when used for 12-bit image 2/11/2010 HO
    Filterchannel = uint16(Filterchannel>0);
elseif strcmp(vDataSet.mType, 'eTypeFloat')
    Filterchannel = single(Filterchannel>0);
end

%% Save the mask as tif image file

Filterchannel = uint8(Filterchannel);
% correct for x y switch between Imaris and matlab
Mask = zeros(size(Filterchannel,2),size(Filterchannel,1),size(Filterchannel,3));
Mask = uint8(Mask);
for i=1:size(Filterchannel,3)
    Mask(:,:,i) = Filterchannel(:,:,i)';
end

TPN = uigetdir;
TPN = [TPN filesep];
saveastiff(Mask, [TPN 'Mask.tif']);

disp(['Mask saved successfully as ' TPN 'Mask.tif']);
end