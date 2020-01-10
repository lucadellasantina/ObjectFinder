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
%        <Item name="ObjectFinder Mask channel with Filament" icon="Matlab" tooltip="Mask channel with Filament. -AB">
%          <Command>Matlab::ObjectFinderMaskChannelWithFilament(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpFilament">
%          <Item name="ObjectFinder Mask channel with Filament" icon="Matlab" tooltip="Mask channel with Filament. -AB">
%            <Command>Matlab::ObjectFinderMaskChannelWithFilament(%i)</Command>
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
function ObjectFinderMaskChannelWithFilament(aImarisApplicationID)

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
        cnt = cnt + 1;
        vFilaments{cnt} = vSurpassScene.GetChild(vChildIndex - 1); %#ok
    end
end

%% choose the correct Filament
vFilamentsCnt = length(vFilaments);
for n = vFilamentsCnt:-1:1
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

xyum = (vImarisApplication.mDataSet.mExtendMaxX-vImarisApplication.mDataSet.mExtendMinX)/vSizeX;
zum = (vImarisApplication.mDataSet.mExtendMaxZ-vImarisApplication.mDataSet.mExtendMinZ)/vSizeZ;

vDataSet = vImarisApplication.mDataSet;% 20101106 AB dont use clone it eats memory, just asign vDataSet to the current dataset
%% user input of channel for masking

vAnswer = inputdlg({sprintf(['Choose channel and filter for mask:\n', ...
    'Channel names: 1, 2, ...\n']), ...
    sprintf('Type extra radius in xy direction added to dendrite radius for masking in um:\n'), ...
    sprintf('Type extra radius in z direction added to dendrite radius AND xy extra radius for masking in um:\n'), ...
    sprintf('Type radius of cell soma that you want to exclude from mask in um (0 for no exclusion):\n'), ...
    sprintf('xy voxel size in um:\n'), sprintf('z voxel size in um:\n'), sprintf('Show the mask in Imaris? (1 for Yes, 0 for No):\n'), ...
    sprintf('Save the mask in Matlab? (1 for Yes, 0 for No):\n')}, 'Choose Channel', 1, {'2','1','0.5','10',num2str(xyum),num2str(zum),'1','1'});
if isempty(vAnswer)
    return
end

vChannel = str2double(vAnswer(1))-1; % channels in Imaris are 0,1,2,3,etc..
XYExtraRad = str2double(vAnswer(2));
ZExtraRad = str2double(vAnswer(3));

%1um extra xy and 0.5um more extra z worked well for PSD95, doing it with
%0.5um extra xy cut some puncta and didn't change the processing time so
%much. 1.5um extra xy and 0.5um more extra z worked well for CtBP2. HO
SomaRad = str2double(vAnswer(4));
vVoxSizeXY = str2double(vAnswer(5));
vVoxSizeZ = str2double(vAnswer(6));
ShowFlag = str2double(vAnswer(7));
SaveFlag = str2double(vAnswer(8));

%% get filament positions parameters

vFilamentAPosXYZ = vFilament.GetPositionsXYZ;
vFilamentARadius = vFilament.GetRadii';
%vFilamentAEdges  = vFilament.GetEdges;

%% create elipsoidal mask around filament

SomaPtID = vFilament.GetRootVertexIndex; %this tells the index of dendrite beginning point, which is typically set to soma, and tyically zero if you didn't change it after Autopath
SomaPtXYZ = vFilamentAPosXYZ(SomaPtID+1,:);
if strcmp(vDataSet.mType, 'eTypeUInt8') %better to use 8bit than 12bit because 12bit (using uint16) makes it too slow HO
    Filterchannel = zeros(vSizeX, vSizeY, vSizeZ, 'uint8');
elseif strcmp(vDataSet.mType, 'eTypeUInt16') %this was eTypeInt16 instead of eTypeUInt16 thus generating error when used for 12-bit image 2/11/2010 HO
    Filterchannel = zeros(vSizeX, vSizeY, vSizeZ, 'uint16');
elseif strcmp(vDataSet.mType, 'eTypeFloat')
    Filterchannel = zeros(vSizeX, vSizeY, vSizeZ, 'single');
end
%flip x and y for meshgrid to adjust to Filterchannel
[meshY, meshX, meshZ] = meshgrid(single(vVoxSizeXY/2:vVoxSizeXY:vVoxSizeXY*vSizeY-vVoxSizeXY/2), single(vVoxSizeXY/2:vVoxSizeXY:vVoxSizeXY*vSizeX-vVoxSizeXY/2),single( vVoxSizeZ/2:vVoxSizeZ:vVoxSizeZ*vSizeZ-vVoxSizeZ/2));

for i=1:length(vFilamentARadius)
    if sqrt((vFilamentAPosXYZ(i,1)-SomaPtXYZ(1)).^2 + (vFilamentAPosXYZ(i,2)-SomaPtXYZ(2)).^2 + (vFilamentAPosXYZ(i,3)-SomaPtXYZ(3)).^2) >= SomaRad
        
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
%% imaging to see the filtered channel
%
% subplot(2,2,1)
% colormap(gray)
% Filchannel255 = Filchannel.*255;
% image(max(Filchannel255,[],3))
% subplot(2,2,2)
% Filterchannel255 = Filterchannel.*255;
% image(max(Filterchannel255,[],3))
% for i = 1:length (Filterchannel255(1,1,:));
%     zFilchannel255(:,i,:) = Filchannel255(:,:,i);
% end
% subplot(2,2,3)
% image(max(zFilchannel255,[],3))
% for i = 1:length (Filterchannel255(1,1,:));
%     zFilterchannel255(:,i,:) = Filterchannel255(:,:,i);
% end
% subplot(2,2,4)
% image(max(zFilterchannel255,[],3))

%% make new channel
if ShowFlag == 1 %showing option added HO 1/19/2010
    vDataSet.mSizeC = vSizeC+1; % 20101106 AB added placement for new masked channel
    vTime = 0;
    for vSlice = vDataSet.mSizeZ-1:-1:0 % down stepping preallocates vDataMask size for increased speed
        vData = vDataSet.GetDataSlice(vSlice,vChannel,vTime);
        vDataMasked(:,:,vSlice+1) = vData.*Filterchannel(:,:,vSlice+1); %20101106AB added vDataMasked to hold masked data to be added with vDataSet.setDataVolume see below
    end
    if strcmp(vDataSet.mType, 'eTypeUInt8') %better to use 8bit than 12bit because 12bit (using uint16) makes it too slow HO
        vDataMasked = uint8(vDataMasked);
    elseif strcmp(vDataSet.mType, 'eTypeUInt16') %this was eTypeInt16 instead of eTypeUInt16 thus generating error when used for 12-bit image 2/11/2010 HO
        vDataMasked = uint16(vDataMasked);
    elseif strcmp(vDataSet.mType, 'eTypeFloat')
        vDataMasked = single(vDataMasked);
    end
    vDataSet.SetDataVolume(vDataMasked,vSizeC,vTime); % 20101106 AB set datavolume instead of setting slices.
end

%% Save the mask (D.mat) and the masking conditions HO 1/10/2010
if SaveFlag == 1
    Filterchannel = uint8(Filterchannel);
    % correct for x y switch between Imaris and matlab
    Mask = zeros(size(Filterchannel,2),size(Filterchannel,1),size(Filterchannel,3));
    Mask = uint8(Mask);
    for i=1:size(Filterchannel,3)
        Mask(:,:,i) = Filterchannel(:,:,i)';
    end
    
    TPN = uigetdir;
    TPN = [TPN filesep];
    save([TPN 'Mask.mat'], 'Mask');

    Settings.TPN = TPN;
    Settings.Mask.XYExtraRad = XYExtraRad;
    Settings.Mask.ZExtraRad = ZExtraRad;
    Settings.Mask.SomaRad = SomaRad;
    save([TPN 'Settings.mat'], 'Settings');
    
    disp('Mask saved successfully!');
end
end
%% Comments and error log
% 091409 DOB unknown AB
% 121609 HO Modified to mask using elipsoid whose radius equals the sum of
% Imaris aRadius and an extra length defined in the prompt.
% 010810 HO Added the exclusion of soma from mask.
% 011010 HO Added the saving option for the mask (D.mat) and the masking
% conditions (Settings.Mask).
% 011910 HO Added the option of showing the resultant mask in Imaris. I
% made this option because this part takes long time and sometimes you may
% want to omit it.
% 062510 HO changed the saving of masking conditions from under Settings to
% just Mask.mat so that when generating multiple masks from the same
% filament (for example different masks for searching for presynaptic
% puncta or postsynaptic puncta), you don't overwrite Settings.Mask.
% Instead, you have to manually move the masking conditions under Settings.
% 20110118 adam reworked meshgrid to use single instead of double to
% minimize memory eating. Also added in checks for accessing the correct
% class of dataset used in imaris to minimize memory drag. hopefully
% program will be faster now.
%
% think about using scaling addition of radius opposed to additive radius

