%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2020 Luca Della Santina
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
function srcObjs = calcNN(srcObjs, dstObjs)
%% Calculate nearest neighbor distance between two sets of objects

if isempty(srcObjs) || isempty(dstObjs)
    return
end

% Calculate nearest neighbor's distance and overlap
xyum        = srcObjs.Settings.ImInfo.xyum;
zum         = srcObjs.Settings.ImInfo.zum;
tmpPts1     = srcObjs.Pos;
tmpVol1     = srcObjs.Vol;
tmpPts2     = dstObjs.Pos;
tmpPts1N    = size(tmpPts1,1);
NN          = struct;
NN.Name     = dstObjs.Name;
IncludeSelf = ~strcmp(srcObjs.UID, dstObjs.UID); % Do not include self if calculating NN of objects against themselves
tic;
disp([' Calculating pairwise nearest neighbors (' srcObjs.Name '->' dstObjs.Name ')']);
for p1 = tmpPts1N:-1:1 % NN distance (Nearest p2 to each p1)
    xyDist  = hypot( (tmpPts1(p1,1)-tmpPts2(:,1))*xyum, (tmpPts1(p1,2)-tmpPts2(:,2))*xyum);
    xyzDist = hypot( xyDist, (tmpPts1(p1,3)-tmpPts2(:,3))*zum); % calculate separately along Z because this dimension has different pixel size
    if IncludeSelf
        p2Distance = min(xyzDist);                 % Distance to nearest neighbor
    else
        p2Distance = min(setdiff(xyzDist(:), min(xyzDist(:)))); % Distance to 2nd nearest neighbor (1st is self)
    end
    
    p2 = find(xyzDist == p2Distance);    % Index of the nearest neighbor
    p2overlap = zeros(size(p2));
    if numel(p2) >1 % Multiple neighbors at min distance, pick one with most overlap        
        for i = 1:numel(p2)
            p2overlap(i) = numel(intersect(srcObjs.Vox(p1).Ind, dstObjs.Vox(p2(i)).Ind));
        end
        p2 = p2(find(p2overlap == max(p2overlap),1));
    end
    NN.Dist(p1)       = p2Distance;                       % Store calibrated distance
    NN.NeighborIdx(p1)= p2;                               % Store neighbor's index
    NN.VoxOverlap(p1) = numel(intersect(srcObjs.Vox(p1).Ind, dstObjs.Vox(p2).Ind));
    NN.VoxOverlapPerc(p1) = 100 * NN.VoxOverlap(p1) / tmpVol1(p1); % Store voxel overlap as percent of source object volume
end

if isempty(fieldnames(srcObjs.NN))
    srcObjs.NN = NN;
else
    % Check if we need to replace a previously done analysis with same mask
    FoundColocManual  = false;
    for i = 1:numel(srcObjs.NN)
        if strcmp(srcObjs.NN(i).Name, NN.Name)
            srcObjs.NN(i) = NN;
            FoundColocManual = true;
            break
        end
    end
    
    % If nothing to replace, just append to the list
    if ~FoundColocManual
        srcObjs.NN(end+1) = NN;
    end
end
disp([' -- done in ' num2str(toc) ' seconds']);

end