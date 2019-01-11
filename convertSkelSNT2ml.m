%% simpleneuritetracer2ml - import ImageJ's simple neurite tracer skeletons
%  Copyright (C) 2011-2018 Luca Della Santina
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
% Convert Fiji's Simple Neurite Tracer skeleton file to matlab
% Skeleton files are GZipped XML .skel, specifications available at:
% http://fiji.lbl.gov/mediawiki/phase3/index.php/Simple_Neurite_Tracer:_.skel_File_Format
%
% Resulting matlab structures are composed by the following fields:
%
% skel
% |
% |- calib = (x,y,z) micron/pixel calibration of the skeletonized image
% |- imgsize = (width, height, depth) pixel size of the skeletonized image
% |- totalLength = total dendritic length of the skeleton in micron
% |- branches = individual branches skeletonized, each item is a polygon
%     |- id = unique identifier for the branch
%     |- idParent = id for the parent of this branch (-1 = primary branch)
%     |- idPrimary = id of the primary branch connected to this
%     |- order = branching order (1 = primary branch = originating at soma)
%     |- length = length of the current segment
%     |- Points = coordinates of each node (rows)[x um,y um ,z um,x um,y um ,z um,radius]
%
% SkelOld
% |
% |- SegStats= representation of the skeleton in legacy format
% |   |- Seg = List of connected segments (numSegments x XYZ x endpoints)
% |   |- Lengts Lengths of each segment in real world units
% |
% |- FilStats = representation of the skeleton in Imaris format 
%     |- aXYZ = XYZ real world coordinates of each point
%     |- aRad = Radius size of each point
%     |- aEdges = indexes of connected points, 2 by 2, first point id = 0
%     |- SomaPtID = ID of point representing the soma (usually = 0)
%     |- SomaPtXYZ = XYZ real world coordinates of soma point
%
% Parameters
%
% PathName : path to the skeleton file
% FileName: name of the skeleton file to load
%

function [SkelOld, skel] = convertSkelSNT2ml(PathName, FileName)
%%
fprintf('loading skeleton file...');

tmpName = gunzip(fullfile(PathName, FileName));
tmpDoc = xmlread(tmpName{1});

skel = struct;

tmpTracings = tmpDoc.getDocumentElement;                       % Get the 'tracings' node
tmpEntries = tmpTracings.getChildNodes;

% Load skeleton file
tmpNode = tmpEntries.getFirstChild;
while ~isempty(tmpNode)
    if strcmp(tmpNode.getNodeName, 'samplespacing')
        % Get image calibration

        skel.calib.x = str2double(tmpNode.getAttributes.getNamedItem('x').getNodeValue);
        skel.calib.y = str2double(tmpNode.getAttributes.getNamedItem('y').getNodeValue);
        skel.calib.z = str2double(tmpNode.getAttributes.getNamedItem('z').getNodeValue);
    elseif strcmp(tmpNode.getNodeName, 'imagesize')
        % Get image size

        skel.imgsize.width = str2double(tmpNode.getAttributes.getNamedItem('width').getNodeValue);
        skel.imgsize.height = str2double(tmpNode.getAttributes.getNamedItem('height').getNodeValue);
        skel.imgsize.depth = str2double(tmpNode.getAttributes.getNamedItem('depth').getNodeValue);
    elseif strcmp(tmpNode.getNodeName, 'path')
        % Get skeleton branches

        if tmpNode.hasAttribute('fittedversionof')
            tmpNode = tmpNode.getNextSibling;
            continue; % skip the note if we're dealing with a fitted version
        end
        tmpBranch = struct;

        % General properties of the branch
        tmpBranch.id = str2double(tmpNode.getAttributes.getNamedItem('id').getNodeValue);
        tmpBranch.length = str2double(tmpNode.getAttributes.getNamedItem('reallength').getNodeValue);
        if isempty(tmpNode.getAttributes.getNamedItem('startson'))
            tmpBranch.idParent = -1;
        else
            tmpBranch.idParent = str2double(tmpNode.getAttributes.getNamedItem('startson').getNodeValue);
            % write here code to store branching position from parent dendrite
        end

        % Individual points constituting the branch
        tmpBranch.points = ones(1, 7);
        tmpPoints = tmpNode.getChildNodes;
        tmpPoint = tmpPoints.getFirstChild;
        i = 0;
        while ~isempty(tmpPoint)
            if strcmp(tmpPoint.getNodeName, 'point')
                tmpPos = struct;
                tmpPos.x = str2double(tmpPoint.getAttributes.getNamedItem('x').getNodeValue);
                tmpPos.y = str2double(tmpPoint.getAttributes.getNamedItem('y').getNodeValue);
                tmpPos.z = str2double(tmpPoint.getAttributes.getNamedItem('z').getNodeValue);
                tmpPos.xd = str2double(tmpPoint.getAttributes.getNamedItem('xd').getNodeValue);
                tmpPos.yd = str2double(tmpPoint.getAttributes.getNamedItem('yd').getNodeValue);
                tmpPos.zd = str2double(tmpPoint.getAttributes.getNamedItem('zd').getNodeValue);

                tmpPos.r = 0;

                i = i+1;
                % x and y positions are inverted in the .trces file as
                % compare to original image stacks, inverting back here
                tmpBranch.points(i, :)= [tmpPos.y, tmpPos.x, tmpPos.z, tmpPos.yd, tmpPos.xd, tmpPos.zd, tmpPos.r];
            end
            tmpPoint = tmpPoint.getNextSibling;
        end

        % Append branch to current cell branches list
        if ~isfield(skel,'branches')
            skel.branches(1) = tmpBranch;
        else
            skel.branches(numel(skel.branches)+1) = tmpBranch;
        end
    end

    tmpNode = tmpNode.getNextSibling;


end

% Calculate additional parameters for the skeleton

% Total dendritic length
tmpTotalLen = 0;
for i=1:numel(skel.branches)
    tmpBranch = skel.branches(i);
    tmpTotalLen = tmpTotalLen + tmpBranch.length;
end
skel.totalLength = tmpTotalLen;

% Branching order (1= primary dendrite)
tmpOrd = 1;
tmpOrdIdx = [-1];
tmpNextOrdIdx = [];

while ~isempty(tmpOrdIdx)

    for i=1:numel(skel.branches)
        if ismember(skel.branches(i).idParent, tmpOrdIdx)
            skel.branches(i).order = tmpOrd;                              % Store branching order value
            tmpNextOrdIdx = cat(1, tmpNextOrdIdx, skel.branches(i).id);   % Populate nodes of the next order
        end
    end
    skel.maxOrder = tmpOrd;
    tmpOrd = tmpOrd + 1;
    tmpOrdIdx = tmpNextOrdIdx;
    tmpNextOrdIdx = [];
end

% Primary dendrite generating each branch
tmpPrim = [];
tmpPrimVertex = []; % initial point of primary dendrites (to find soma)

for i=1:numel(skel.branches)
    if skel.branches(i).idParent == -1
        tmpPrim = cat(1,tmpPrim, skel.branches(i).id);
        tmpPrimVertex(numel(tmpPrim), :) = skel.branches(i).points(1,:);
    end
end

for i=1:numel(tmpPrim)
    tmpBranchList = [tmpPrim(i)];
    for j=1:numel(skel.branches)
        if ismember(skel.branches(j).idParent, tmpBranchList) || ...
                ismember(skel.branches(j).id, tmpBranchList)

            tmpBranchList = cat(1, tmpBranchList, skel.branches(j).id);
            skel.branches(j).idPrimary = tmpPrim(i);
        end
    end
end
skel.primaryDendrites = numel(tmpPrim);
fprintf('DONE\n');

%% Convert to old Skel format (segment means position and length)
fprintf('Converting skeleton file format...');
Seg = [];
nSeg = 0;
Lengths = [];

% Reconstruct segment connectivity into a list, 2 points at a time 
for branch = 1:numel(skel.branches)
    for point = 2 : size(skel.branches(branch).points,1)
        nSeg = nSeg + 1;
        Seg(nSeg, :, 1) = skel.branches(branch).points(point-1, 4:6);
        Seg(nSeg, :, 2) = skel.branches(branch).points(point  , 4:6);
    end
end
Lengths= sqrt((Seg(:,1,1)-Seg(:,1,2)).^2 + (Seg(:,2,1)-Seg(:,2,2)).^2  + (Seg(:,3,1)-Seg(:,3,2)).^2);

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
for branch = 1:numel(skel.branches)    
    for point = 1 : size(skel.branches(branch).points,1)
        nPoint = nPoint + 1;
        aXYZ(nPoint, :) = skel.branches(branch).points(point, 4:6);
        aRad(nPoint, :) = skel.branches(branch).points(point, 7);
        if point >=2
            nSeg = nSeg + 1;
            % Edges indexes start with zero because of Imaris C/C++
            aEdges(nSeg, 1) = nPoint -2;
            aEdges(nSeg, 2) = nPoint -1;
        end
    end
end
SkelOld.FilStats.aXYZ      = single(aXYZ);
SkelOld.FilStats.aRad      = single(aRad');
SkelOld.FilStats.aEdges    = uint32(aEdges);
SkelOld.FilStats.SomaPtID  = 0;
SkelOld.FilStats.SomaPtXYZ = SkelOld.FilStats.aXYZ(1,:);
fprintf('DONE\n');

%clear tmp* i j;
end
