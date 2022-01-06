%% Instructions
%
%  Save Spots as ObjectFinder's set of objects
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Spots Functions">
%        <Item name="ConvertSpots2ObjectFinder" icon="Matlab" tooltip="ConvertSpots2ObjectFinder">
%          <Command>Matlab::ConvertSpots2ObjectFinder(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="ConvertSpots2ObjectFinder" icon="Matlab" tooltip="ConvertSpots2ObjectFinder">
%            <Command>Matlab::ConvertSpots2ObjectFinder(%i)</Command>
%          </Item>
%        </SurpassComponent>
%        <SurpassComponent name="bpSpots">
%          <Item name="ConvertSpots2ObjectFinder" icon="Matlab" tooltip="ConvertSpots2ObjectFinder">
%            <Command>Matlab::ConvertSpots2ObjectFinder(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
%
%  
%  Description:
%
%   The User chooses which spots to export, coordinates of spots are
%   represented as rows of the SpotXYZ matrix, [X,Y,Z] 
%   Coordinates are expressed in pixel
%
%% Connect to Imaris Com interface
function ConvertSpots2ObjectFinder(aImarisApplicationID)

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

%% get image size and pixel resolution
tmpDataset = vImarisApplication.mDataset; %get the dataset to retrieve size/resolution
xs = tmpDataset.mSizeX; %X size in pixel
ys = tmpDataset.mSizeY; %Y size in pixel
zs = tmpDataset.mSizeZ; %Z size in pixel
xsReal = tmpDataset.mExtendMaxX - tmpDataset.mExtendMinX; %X size in micron
ysReal = tmpDataset.mExtendMaxY - tmpDataset.mExtendMinY; %Y size in micron
zsReal = tmpDataset.mExtendMaxZ - tmpDataset.mExtendMinZ; %Z size in micron
xr = xsReal/xs; %X pixel resolution (usually micron per pixel)
yr = ysReal/ys; %Y pixel resolution (usually micron per pixel)
zr = zsReal/zs; %Z pixel resolution (usually micron per pixel)

%% make directory of Spots in surpass scene
cnt = 0;
for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
    if vImarisApplication.mFactory.IsSpots(vSurpassScene.GetChild(vChildIndex - 1))
        cnt = cnt+1;
        vSpots{cnt} = vSurpassScene.GetChild(vChildIndex - 1); %#ok
    end
end

%% choose passing spots
vSpotsCnt = length(vSpots);
for n= 1:vSpotsCnt
    vSpotsName{n} = vSpots{n}.mName; %#ok
end
cellstr = cell2struct(vSpotsName,{'names'},vSpotsCnt+2);
str = {cellstr.names};
[vAnswer_iPass,~] = listdlg('ListSize',[200 160], ... 
    'PromptString','Chose spots to export',...
    'SelectionMode','multiple',...
    'ListString',str);

%% Create an ObjectFinder set for the current Imaris Spots

Dots         = struct;
Dots.Name    = str{vAnswer_iPass};

tmp          = java.util.UUID.randomUUID;
tmpStr       = tmp.toString;
Dots.UID     = tmpStr.toCharArray';
Dots.Shape   = struct;
Dots.Density = struct; % Density measurements
Dots.NN      = struct; % Nearest neighbor measurements
Dots.Coloc   = struct; % Colocalization measurements
Dots.Skel    = struct; % Skeleton measurements (e.g distance to cell body)

Dots.Settings.Version = 10.0;
Dots.Settings.debug = 0;
Dots.Settings.ImInfo.DenCh = 0;
Dots.Settings.ImInfo.PostCh = 0;
Dots.Settings.ImInfo.ColoCh = 0;
Dots.Settings.ImInfo.xyum = xr;
Dots.Settings.ImInfo.zum = zr;
Dots.Settings.ImInfo.xNumVox = xs;
Dots.Settings.ImInfo.yNumVox = ys;
Dots.Settings.ImInfo.zNumVox = zs;
Dots.Settings.ImInfo.PostChName = '';
Dots.Settings.ImInfo.CBpos = [1 1 1];
Dots.Settings.ImInfo.MedFilt = 0;
Dots.Settings.ImInfo.MedFiltKern = 0;

Dots.Settings.objfinder.blockSize = 90;
Dots.Settings.objfinder.blockBuffer = 15;
Dots.Settings.objfinder.thresholdStep = 2;
Dots.Settings.objfinder.maxDotSize = 2;
Dots.Settings.objfinder.minDotSize = 1;
Dots.Settings.objfinder.itMin = 1;
Dots.Settings.objfinder.minFinalDotSize = 1;
Dots.Settings.objfinder.watershed = 0;
Dots.Settings.objfinder.blockSearch = 0;
Dots.Settings.objfinder.sphericity = 0;
Dots.Settings.objfinder.minIntensity = 1;

% Add coordinates of each spot, size will be one voxel
for i = 1:numel(vAnswer_iPass)
    iPassSpots = vSpots{vAnswer_iPass(i)};
    [SpotsXYZ,~,~] = iPassSpots.Get;
    SpotsXYZ(:,1) = ceil(SpotsXYZ(:,1)./xr); %convert coordinates to pixel
    SpotsXYZ(:,2) = ceil(SpotsXYZ(:,2)./yr); %convert coordinates to pixel
    SpotsXYZ(:,3) = ceil(SpotsXYZ(:,3)./zr); %convert coordinates to pixel
end
Dots.Num = size(SpotsXYZ,1);
Dots.Pos = SpotsXYZ;
Dots.Vol = ones(1,size(Dots.Pos, 1), 'double');
Dots.ITMax = ones(1,size(Dots.Pos, 1), 'uint8');
Dots.ItSum = ones(1,size(Dots.Pos, 1), 'double');
Dots.MeanBright = ones(1,size(Dots.Pos, 1), 'single');

% populate the Vox field for each spot
for i = 1:size(Dots.Pos, 1)
    Dots.Vox(i).Pos = Dots.Pos(i,:);
    Dots.Vox(i).Ind = i;
    Dots.Vox(i).RawBright = 1;
    Dots.Vox(i).IT = i;
end

Dots.Settings.Filter.EdgeDotCut = 0;
Dots.Settings.Filter.SingleZDotCut = 0;
Dots.Settings.Filter.xyStableDots = 0;
Dots.Settings.Filter.Thresholds.ITMax = 0;
Dots.Settings.Filter.Thresholds.ITMaxDir = 1;
Dots.Settings.Filter.Thresholds.Vol = 0;
Dots.Settings.Filter.Thresholds.VolDir = 1;
Dots.Settings.Filter.Thresholds.MinBright = 0;
Dots.Settings.Filter.Thresholds.MinBrightDir = 1;
Dots.Settings.Filter.Thresholds.Oblong = 0;
Dots.Settings.Filter.Thresholds.OblongDir = 1;
Dots.Settings.Filter.Thresholds.PrincipalAxisLen = 0;
Dots.Settings.Filter.Thresholds.PrincipalAxisLenDir = 1;
Dots.Settings.Filter.Thresholds.Zposition = 0;
Dots.Settings.Filter.Thresholds.ZpositionDir = 1;
Dots.Settings.Filter.Thresholds2 = Dots.Settings.Filter.Thresholds;

Dots.Filter.passF = ones(size(Dots.Pos,1),1,'logical');
Dots.FilterOpts = Dots.Settings.Filter;

%% Save objects set to disk

TPN = uigetdir;
folder   = [TPN filesep 'objects'];
FileName = [folder filesep Dots.UID '.mat'];
if ~isfolder(folder), mkdir(folder); end
save(FileName, '-struct', 'Dots', '-v7');

fprintf('Spots converted!')    

