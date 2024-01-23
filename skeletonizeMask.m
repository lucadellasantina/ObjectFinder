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
function [SkelOld, SkelNew] = skeletonizeMask(MaskChName)
%% Read Mask Image and find soma position
FileName = [pwd filesep 'I' filesep MaskChName];

% Read the image size and resolution from file
tmpImInfo = imfinfo(FileName);
tmpImSizeZ = numel(tmpImInfo);
tmpImSizeX = tmpImInfo.Width;
tmpImSizeY = tmpImInfo.Height;

% Read image resolution data
try
    tmpXYres = 1/tmpImInfo(1).XResolution;
    if contains(tmpImInfo(1).ImageDescription, 'spacing=')
        tmpPos = strfind(tmpImInfo(1).ImageDescription,'spacing=');
        tmpZres = tmpImInfo(1).ImageDescription(tmpPos+8:end);
        tmpZres = regexp(tmpZres,'\n','split');
        tmpZres = str2double(tmpZres{1});
    else
        tmpZres = 0.3; % otherwise use default value
    end
    ImRes = [tmpXYres, tmpXYres, tmpZres];
catch
    ImRes = [1,1,1];
end


% Load the image data into matlab
fprintf('Loading image stack... ');
I = uint8(ones(tmpImSizeX, tmpImSizeY, tmpImSizeZ));
for j = 1:tmpImSizeZ
    I(:,:,j)=imread(FileName, j);
end
mask = I==1;
fprintf('DONE\n');

S.xyum = ImRes(1);
S.zum = ImRes(3);
%S.radius = 52;
S = editStruct(S);

SkelNew.calib.x = S.xyum;
SkelNew.calib.y = S.xyum;
SkelNew.calib.z = S.zum;
SkelNew.imgsize.width  = size(mask(2));
SkelNew.imgsize.height = size(mask(1));
SkelNew.imgsize.depth  = size(mask(3));

fprintf('Searching soma... ');
AreaMax = 0;
AreaMaxPos = [1 1 1];
AreaMaxRad = 0;
for z = 1:size(mask,3)
    RP = regionprops(mask(:,:,z),'Area', 'Centroid', 'MajorAxisLength');
    if max([RP.Area]) > AreaMax
        AreaMax = max([RP.Area]);
        AreaMaxPos = [RP([RP.Area]==AreaMax).Centroid(2), RP([RP.Area]==AreaMax).Centroid(1), z];
        AreaMaxRad = RP([RP.Area]==AreaMax).MajorAxisLength;
    end
end
SomaPos = AreaMaxPos;
SomaRad = AreaMaxRad;
fprintf('DONE\n');
clear z r Area*

fprintf('Skeletonizing...');
skel = bwskel(mask, 'MinBranchLength', 0);
[~,nodes,link] = Skel2Graph3D(skel, 0);
fprintf('DONE\n');

%% Convert to old Skel format (segment means position and length)
fprintf('Converting skeleton file format...');
Seg = [];
nSeg = 0;
Lengths = [];

% Reconstruct segment connectivity into a list, 2 points at a time 
for l=1:numel(link)
    for point = 1 : numel(link(l).point)
        [x, y, z] = ind2sub(size(mask), link(l).point(point));
        SkelNew.branches(l).points(point,:) = [y,x,z,y*S.xyum,x*S.xyum,z*S.zum,0];
        SkelOld.branches(l).XYZ(point,:) = [y*S.xyum,x*S.xyum,z*S.zum];
    end
    
    nSegStart = max(1,nSeg);    
    for point = 2 : numel(link(l).point)
        nSeg = nSeg + 1;
        [x1, y1, z1] = ind2sub(size(mask), link(l).point(point-1));
        Seg(nSeg, :, 1) = [y1, x1, z1];
        [x2, y2, z2] = ind2sub(size(mask), link(l).point(point));
        Seg(nSeg, :, 2) = [y2, x2, z2];
    end

    % Calculate branch length in calibrated units
    SkelNew.branches(l).length = ...
         sum(sqrt( ((Seg(nSegStart:end,1,1)-Seg(nSegStart:end,1,2))*S.xyum).^2 +...
               ((Seg(nSegStart:end,2,1)-Seg(nSegStart:end,2,2))*S.xyum).^2  +...
               ((Seg(nSegStart:end,3,1)-Seg(nSegStart:end,3,2))*S.zum).^2));
    
end
Lengths= sqrt( (Seg(:,1,1)-Seg(:,1,2)).^2 +...
               (Seg(:,2,1)-Seg(:,2,2)).^2  +...
               (Seg(:,3,1)-Seg(:,3,2)).^2);

% Total dendritic length
tmpTotalLen = 0;
for i = 1:numel(SkelNew.branches)
    tmpBranch = SkelNew.branches(i);
    tmpTotalLen = tmpTotalLen + tmpBranch.length;
end
SkelNew.totalLength = tmpTotalLen;

SkelOld.SegStats.Seg = single(Seg);
SkelOld.SegStats.Lengths = single(Lengths);

% Reconstruct filament connectivity, 1 point at a time
aXYZ    = [];
aRad    = [];
aEdges  = [];
nPoint  = 0;
nSeg    = 0;

% TODO in order to reconstruct aEdges, we need to take into account the
% idParent otherwise IDs continue to grow indefinitely 
for l=1:numel(link) 
    for point = 1 : numel(link(l).point)
        nPoint = nPoint + 1;
        [x, y, z] = ind2sub(size(mask), link(l).point(point));
        aXYZ(nPoint, :) = [y, x, z];
        aRad(nPoint, :) = 0;
        if point >=1
            nSeg = nSeg + 1;
            aEdges(nSeg, 1) = nPoint -1;
            aEdges(nSeg, 2) = nPoint;
        end
    end
end
SkelOld.FilStats.aXYZ      = single(aXYZ);
SkelOld.FilStats.aRad      = single(aRad');
SkelOld.FilStats.aEdges    = uint32(aEdges);
SkelOld.FilStats.SomaPtID  = 0;
SkelOld.FilStats.SomaPtXYZ = [SomaPos(2)*S.xyum, SomaPos(1)*S.xyum, SomaPos(3)*S.zum];
SkelOld.FilStats.SomaPtRad = SomaRad;
fprintf('DONE\n');

end
