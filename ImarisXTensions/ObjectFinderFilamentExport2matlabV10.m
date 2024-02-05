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
%        <Item name="ObjectFinder Export Filament to MATLAB V10" icon="Matlab" tooltip="Save Filament as .mat">
%          <Command>Matlab::ObjectFinderFilamentExport2matlabV10(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpFilament">
%          <Item name="ObjectFinder Export Filament to MATLAB V10" icon="Matlab" tooltip="Save Filament as .mat">
%            <Command>Matlab::ObjectFinderFilamentExport2matlabV10(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
%
%  Description: User selects a filament that will be exported as .mat
%  Matlab file to be processed by ObjectFinder.


%% connect to Imaris Com interface
function ObjectFinderFilamentExport2matlabV10(aImarisApplicationID)

% connect to Imaris interface
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
  javaaddpath ImarisLib.jar
  vImarisLib = ImarisLib;
  if ischar(aImarisApplicationID)
    aImarisApplicationID = round(str2double(aImarisApplicationID));
  end
  vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
else
  vImarisApplication = aImarisApplicationID;
end

% get the filament
vFactory = vImarisApplication.GetFactory;
vFilaments = vFactory.ToFilaments(vImarisApplication.GetSurpassSelection);

% search the filament if not previously selected
vSurpassScene = vImarisApplication.GetSurpassScene;
if ~vFactory.IsFilaments(vFilaments)        
    for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
        vDataItem = vSurpassScene.GetChild(vChildIndex - 1);
        if vFactory.IsFilaments(vDataItem)
            vFilaments = vFactory.ToFilaments(vDataItem);
            break;
        end
    end
    % did we find the filament?
    if isequal(vFilaments, [])
        msgbox('Please create some filament!');
        return;
    end
end

aXYZ    = vFilaments.GetPositionsXYZ(0);
aRad    = vFilaments.GetRadii(0);
aEdges  = vFilaments.GetEdges(0);

%% Export the position of soma 1/5/2010 HO
SomaPtID = vFilament.GetRootVertexIndex(0); %this tells the index of dendrite beginning point, which is typically set to soma, and tyically zero if you didn't change it after Autopath
if SomaPtID ~= -1 %if dendrite beginning point is not set, Imaris spits out -1.
    SomaPtXYZ = aXYZ(SomaPtID+1,:);
else
    msgbox('Warning: Soma pt (beginning pt) not set. Using posizion with lower Z value')
    vFilament(0).SetRootVertexIndex(find(aXYZ(:,3) == min(aXYZ(:,3)))+1);
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
Skel.Name = aFilament.mName;

% Generate an unique identifier using Java's UUID generator
tmp      = java.util.UUID.randomUUID;
tmpStr   = tmp.toString;
Skel.UID = tmpStr.toCharArray';

%% Save skeleton into the skeletons folder of the project
TPN = uigetdir;
if ~exist([TPN filesep 'skeletons'], 'dir')
    mkdir([TPN filesep 'skeletons']);
end

FileName = [TPN filesep 'skeletons' filesep Skel.UID '.mat']; 
save(FileName, '-struct', 'Skel');
disp('Skeleton exported successfully!');
end
















