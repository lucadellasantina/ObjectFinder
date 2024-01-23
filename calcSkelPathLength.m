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
function Skel = calcSkelPathLength(Skel, ReportStats)
%% This program was modified from HOSkelFinerGenerator.mat.
%This program takes in Skel, march from soma to connected skels while
%registering the path length from soma for each skel point. Then put the
%calculated path length from soma under Skel.FilStats and return.

SkelIDsPool = 1:1:size(Skel.FilStats.aXYZ,1);
SkelIDsConnectivityPool = Skel.FilStats.aEdges;
SkelSegLengthsPool = Skel.SegStats.Lengths;

SomaPtID = Skel.FilStats.SomaPtID+1;
SourceSkelIDs = SomaPtID; % start from soma.
SkelIDsPool(SomaPtID) = []; % deplete the soma point.

SkelPathLength2Soma = zeros(1,size(Skel.FilStats.aXYZ,1));

% March from the soma
fprintf('Marching through current skeleton to calculate lengths ... ');
while ~isempty(SkelIDsPool)
    % length(SkelIDsPool) % how many more skel to process
    if isempty(SourceSkelIDs) % if the previous skel was the dead end, resume from the first entry within the remaining pool.
        SourceSkelIDs = SkelIDsPool(1); 
        SkelIDsPool(1) = []; % deplete the newly grabbed skel.
    end

    NextSkelIDs = [];
    for j=1:length(SourceSkelIDs)
        SourceSkelID = SourceSkelIDs(j);
        [SourceSkelRows, SourceSkelCols] = find(SkelIDsConnectivityPool == SourceSkelID);
        if ~isempty(SourceSkelCols) %if the source skel is not dead end, find the connected partner skel
            NextSkelCols = SourceSkelCols*(-1)+3; %to reverse 1 and 2 to get the partner skel.
            for i=1:length(NextSkelCols)
                SourceSkelRow = SourceSkelRows(i);
                SourceSkelCol = SourceSkelCols(i);
                NextSkelCol = NextSkelCols(i);
                NextSkelID = SkelIDsConnectivityPool(SourceSkelRow, NextSkelCol);
                Lengths2NextSkel = SkelSegLengthsPool(SourceSkelRow);
                
                SkelPathLength2Soma(NextSkelID) = SkelPathLength2Soma(SourceSkelID) + Lengths2NextSkel;
                
                NextSkelIDs = [NextSkelIDs, NextSkelID];
            end
            SkelIDsConnectivityPool(SourceSkelRows,:) = []; % deplete the found connectivity from the pool.
            SkelSegLengthsPool(SourceSkelRows) = []; % also deplete seg lengths
        end
    end

    if ~isempty(NextSkelIDs)
        for id=1:length(NextSkelIDs)
            SkelIDsPool(SkelIDsPool==NextSkelIDs(id)) = []; %deplete the next grabbed skel.
        end
    end
    SourceSkelIDs = NextSkelIDs; %switch next to source for the next loop.
end
fprintf('DONE \n');

if ReportStats
    disp(['Farthest skel path distance is: ' max(SkelPathLength2Soma)]);
    disp(['Soma point ID is (Imaris soma pt ID + 1): ' num2str(SomaPtID)]);
    disp(['Skel IDs of zero path distance are (only soma point should have zero path distance): ' num2str(find(SkelPathLength2Soma==0))]);
end

% Calculated path length of edges by taking the mean of skels
EdgePathLength2Soma = zeros(1,size(Skel.FilStats.aEdges,1));
for i = 1:length(EdgePathLength2Soma)
    EdgePathLength2Soma(i) = mean([SkelPathLength2Soma(Skel.FilStats.aEdges(i,1)), SkelPathLength2Soma(Skel.FilStats.aEdges(i,2))]);
end

% Store the results under Skel.FilStats
Skel.FilStats.SkelPathLength2Soma = SkelPathLength2Soma;
Skel.FilStats.EdgePathLength2Soma = EdgePathLength2Soma;
end