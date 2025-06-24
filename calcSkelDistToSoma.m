%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2025 Luca Della Santina
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
function Skel = calcSkelDistToSoma(Skel)
%% Calculates the distance of each point to soma following skeleton's path 
% This program takes in Skel, march from soma to connected skels while
% registering the path length from soma for each skel point. Then put the
% calculated path length from soma under Skel.FilStats and return.

% Collect cumulative distance from soma to beginning of each branch
DistToBranch = zeros(1, numel(Skel.branches));
for i = 1:numel(Skel.branches)
    posParent = find([Skel.branches.id] == Skel.branches(i).idParent);    
    while posParent > 0
        DistToBranch(i) = DistToBranch(i) + Skel.branches(posParent).length;
        posParent = find([Skel.branches.id] == Skel.branches(posParent).idParent);        
    end
end

%%
% Calculate distance from soma to each point of current branch
pos = 1; % Counter of current position in DistToSoma
DistToSoma = zeros(1, sum( arrayfun(@(x) size(x.points,1), Skel.branches) ));
for i = 1:numel(Skel.branches)
    for p = 1:size(Skel.branches(i).points,1)
        if p == 1
            DistToSoma(pos) = DistToBranch(i);
        elseif size(Skel.branches(i).points,2) == 3
            DistToSoma(pos) = DistToSoma(pos-1) + pdist(Skel.branches(i).points(p-1:p,1:3));
        else           
            DistToSoma(pos) = DistToSoma(pos-1) + pdist(Skel.branches(i).points(p-1:p,4:6));
        end
        pos = pos+1;
    end
end

% Calculated path length of edges by taking the mean of skels
EdgeDistToSoma = zeros(1,size(Skel.FilStats.aEdges,1));
for i = 1:length(EdgeDistToSoma)
    EdgeDistToSoma(i) = mean([DistToSoma(Skel.FilStats.aEdges(i,1)), DistToSoma(Skel.FilStats.aEdges(i,2))]);
end

% Store the results under Skel.FilStats
Skel.FilStats.SkelPathLength2Soma = DistToSoma;
Skel.FilStats.EdgePathLength2Soma = EdgeDistToSoma;

clear i idParent p pos DistToBranch DistToSoma EdgeDistToSoma;
end