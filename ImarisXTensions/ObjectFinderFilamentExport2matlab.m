%% Instructions
%  Select Filament and send to Matlab as Skel.mat files
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%  <CustomTools>
%      <Menu>
%       <Submenu name="Filament Functions">
%        <Item name="ObjectFinder Export Filament to MATLAB" icon="Matlab" tooltip="Save Filament as .mat">
%          <Command>Matlab::ObjectFinderFilamentExport2matlab(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpFilament">
%          <Item name="ObjectFinder Export Filament to MATLAB" icon="Matlab" tooltip="Save Filament as .mat">
%            <Command>Matlab::ObjectFinderFilamentExport2matlab(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
%
%  Description: User selects a filament that will be exported as .mat
%  Matlab file to be processed by ObjectFinder.


%% connect to Imaris Com interface
function ObjectFinderFilamentExport2matlab(aImarisApplicationID)
  
if ~isa(aImarisApplicationID, 'COM.Imaris_Application')
    vImarisServer = actxserver('ImarisServer.Server');
    vImarisApplication = vImarisServer.GetObject(aImarisApplicationID);
else
    vImarisApplication = aImarisApplicationID;
end

%% if testing from matlab (comment when running from Imaris)
%vImarisApplication = actxserver('Imaris.Application');
%vImarisApplication.mVisible = true;

%% the user has to create a scene with some spots and surface

vSurpassScene = vImarisApplication.mSurpassScene;
if isequal(vSurpassScene, [])
    msgbox('Please create Surpass scene!');
    return
end

%% make directory of Filaments in surpass scene
cnt = 0;
for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
    if vImarisApplication.mFactory.IsFilament(vSurpassScene.GetChild(vChildIndex - 1))
        cnt = cnt + 1;
        vFilaments{cnt} = vSurpassScene.GetChild(vChildIndex - 1); %#ok
    end
end

%% Choose which Filaments object to export
vFilamentsCnt = length(vFilaments);
for n = vFilamentsCnt:-1:1
    vFilamentsName{n} = vFilaments{n}.mName;
end
cellstr = cell2struct(vFilamentsName,{'names'},vFilamentsCnt+2);
str = {cellstr.names};

[vAnswer_yes,~] = listdlg('ListSize',[200 160], 'PromptString','Choose Filament:', 'SelectionMode','single','ListString',str);
aFilament = vFilaments{vAnswer_yes};

aXYZ    = aFilament.GetPositionsXYZ;
aRad    = aFilament.GetRadii;
aEdges  = aFilament.GetEdges;

%% Export the position of soma 1/5/2010 HO
SomaPtID = aFilament.GetRootVertexIndex; %this tells the index of dendrite beginning point, which is typically set to soma, and tyically zero if you didn't change it after Autopath
if SomaPtID ~= -1 %if dendrite beginning point is not set, Imaris spits out -1.
    SomaPtXYZ = aXYZ(SomaPtID+1,:);
else
    msgbox('Warning: Soma pt (beginning pt) not set. Using posizion with lower Z value')
    aFilament.SetRootVertexIndex(find(aXYZ(:,3) == min(aXYZ(:,3)))+1);
    SomaPtXYZ = aXYZ(find(aXYZ(:,3) == min(aXYZ(:,3)))+1,:);
end

%% Convert to jm Skel format (segment mean position and length)
Edges   = aEdges+1;
Seg     = cat(3,aXYZ(Edges(:,1),:),aXYZ(Edges(:,2),:));
Lengths = sqrt((Seg(:,1,1)-Seg(:,1,2)).^2 + (Seg(:,2,1)-Seg(:,2,2)).^2 + (Seg(:,3,1)-Seg(:,3,2)).^2);

Skel.FilStats.aXYZ  = aXYZ;
Skel.FilStats.aRad  = aRad;
Skel.FilStats.aEdges= aEdges;

%If dendrite beginning point is not set, Imaris returns -1
if SomaPtID ~= -1
    Skel.FilStats.SomaPtID = SomaPtID;
    Skel.FilStats.SomaPtXYZ = SomaPtXYZ;
end
Skel.SegStats.Seg=Seg;
Skel.SegStats.Lengths=Lengths;
Skel.Name = vAnswer_yes;

% Generate an unique identifier using Java's UUID generator
tmp      = java.util.UUID.randomUUID;
tmpStr   = tmp.toString;
Skel.UID = tmpStr.toCharArray';

% Save skeleton into the skeletons folder of the project
TPN = uigetdir;
if ~exist([TPN filesep 'skeletons'], 'dir')
    mkdir([TPN filesep 'skeletons']);
end

FileName = [TPN filesep 'skeletons' filesep Skel.UID '.mat']; 
save(FileName, '-struct', 'Skel');
disp('Skeleton exported successfully!');
end
















