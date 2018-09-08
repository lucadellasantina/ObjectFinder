%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016,2017,2018 Luca Della Santina
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
function SkelFiner = generateFinerSkel(Skel, maxFinerEdgeLength, debug)
%This program takes in Skel.mat, and make finer Skel to fill the voxel gaps
%with the skel to skel distance at least maxFinerEdgeLength. None of the
%edges will be longer than maxFinerEdgeLength. The result is returned as
%SkelFiner.mat with its format same as Skel.mat.

SkelFinerXYZ = Skel.FilStats.aXYZ; % Keep the original skel IDs
SkelFinerEdges = [];
%SkelFinerSeg = [];
%SkelFinerLengths = [];

SkelIDsPool = 1:1:size(Skel.FilStats.aXYZ,1);
SkelIDsConnectivityPool = Skel.FilStats.aEdges+1; %+1 because Imaris ID starts from zero.
SkelSegPool = Skel.SegStats.Seg;
SkelSegLengthsPool = Skel.SegStats.Lengths;

if isfield(Skel.FilStats, 'SomaPtID') %if soma pt is set in Imaris
    SomaPtID = Skel.FilStats.SomaPtID+1; %+1 because Imaris ID starts from zero.
    SomaPtXYZ = Skel.FilStats.SomaPtXYZ;
    SourceSkelIDs = SomaPtID; %start from soma.
    SkelIDsPool(SomaPtID) = []; %deplete the soma point.
else %soma pt not set in Imaris, just grab ID=1 to start
    SourceSkelIDs = 1;
    SkelIDsPool(1) = [];
end

fprintf('Generating a finer version of the skeleton ... ');
while ~isempty(SkelIDsPool)
    %length(SkelIDsPool) %how many more skel to deplete?
    if isempty(SourceSkelIDs) %if the previous skel was the dead end, resume from the first entry within the remaining pool.
        SourceSkelIDs = SkelIDsPool(1);
        SkelIDsPool(1) = []; %deplete the newly grabbed skel.
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
                %this part was modified from anaMa.
                devs=max(1,ceil(Lengths2NextSkel/maxFinerEdgeLength)); %Find number of subdivisions
                NumNewSkels = devs-1;
                NumEdges = NumNewSkels+1;
                if NumNewSkels==0 % if no need to add extra skels
                    SkelFinerEdges(end+1,:) = [SourceSkelID, NextSkelID];
                else %need to add extra skels
                    NewSkelIDs = size(SkelFinerXYZ,1)+1:1:size(SkelFinerXYZ,1)+NumNewSkels;
                    NewSkelIDs = uint32(NewSkelIDs); %need to use the same class
                    clear sy sx sz;
                    for d=1:NumNewSkels
                        sx(d)=SkelSegPool(SourceSkelRow,1,SourceSkelCol)+((SkelSegPool(SourceSkelRow,1,NextSkelCol)-SkelSegPool(SourceSkelRow,1,SourceSkelCol))/NumEdges)*d;
                        sy(d)=SkelSegPool(SourceSkelRow,2,SourceSkelCol)+((SkelSegPool(SourceSkelRow,2,NextSkelCol)-SkelSegPool(SourceSkelRow,2,SourceSkelCol))/NumEdges)*d;
                        sz(d)=SkelSegPool(SourceSkelRow,3,SourceSkelCol)+((SkelSegPool(SourceSkelRow,3,NextSkelCol)-SkelSegPool(SourceSkelRow,3,SourceSkelCol))/NumEdges)*d;
                    end
                    sy=sy';sx=sx';sz=sz';
                    NewSkelFinerXYZ = [sx, sy, sz];
                    SkelFinerXYZ = [SkelFinerXYZ; NewSkelFinerXYZ];
                    
                    NewSkelIDs = NewSkelIDs';
                    SkelIDSequence = [SourceSkelID; NewSkelIDs; NextSkelID];
                    NewSkelFinerEdges = cat(2, SkelIDSequence(1:end-1), SkelIDSequence(2:end));
                    SkelFinerEdges = [SkelFinerEdges; NewSkelFinerEdges];
                    
                end
                
                NextSkelIDs = [NextSkelIDs, NextSkelID];
            end
            SkelIDsConnectivityPool(SourceSkelRows,:) = []; %deplete the found connectivity from the pool.
            SkelSegLengthsPool(SourceSkelRows) = []; %also deplete seg lengths
            SkelSegPool(SourceSkelRows,:,:) = []; %also deplete seg
        end
    end
    
    if ~isempty(NextSkelIDs)
        for id=1:length(NextSkelIDs)
            SkelIDsPool(SkelIDsPool==NextSkelIDs(id)) = []; %deplete the next grabbed skel.
        end
    end
    SourceSkelIDs = NextSkelIDs; %switch next to source for the next loop.
end
fprintf('DONE\n');

% Convert the finer skel into Skel format.
if debug
    disp('Coarse (original) skeleton statistics');
    disp(['Total coarse skel length is: ' num2str(sum(Skel.SegStats.Lengths))]);
    disp(['Total coarse skel node number is: ' num2str(size(Skel.FilStats.aXYZ,1))]);
    disp(['Total coarse skel edge number is: ' num2str(size(Skel.FilStats.aEdges,1))]);
    disp(['Average coarse skel edge length is: ' num2str(sum(Skel.SegStats.Lengths)/size(Skel.FilStats.aEdges,1))]);
end

SkelFiner.FilStats.aXYZ = SkelFinerXYZ;
SkelFiner.FilStats.aEdges = SkelFinerEdges-1; %-1 to bring it back to Imaris format.

if isfield(Skel.FilStats, 'SomaPtID') %if soma pt is set in Imaris
    SkelFiner.FilStats.SomaPtID = SomaPtID-1; %-1 to bring it back to Imaris format.
    SkelFiner.FilStats.SomaPtXYZ = SomaPtXYZ;
end

% Calculate SegStats
SkelFiner.SegStats.Seg=cat(3, SkelFinerXYZ(SkelFinerEdges(:,1),:), SkelFinerXYZ(SkelFinerEdges(:,2),:));
SkelFiner.SegStats.Lengths =sqrt((SkelFiner.SegStats.Seg(:,1,1)-SkelFiner.SegStats.Seg(:,1,2)).^2 + ...
    (SkelFiner.SegStats.Seg(:,2,1)-SkelFiner.SegStats.Seg(:,2,2)).^2 + ...
    (SkelFiner.SegStats.Seg(:,3,1)-SkelFiner.SegStats.Seg(:,3,2)).^2);

if debug
    disp('Finer (processed) skeleton statistics (total seg length must metch between coarse and finer skeleton)');
    disp(['Total finer skel length is: ' num2str(sum(SkelFiner.SegStats.Lengths))]); 
    disp(['Total finer skel node number is: ' num2str(size(SkelFiner.FilStats.aXYZ,1))]);
    disp(['Total finer skel edge number is: ' num2str(size(SkelFiner.FilStats.aEdges,1))]);
    disp(['Average finer skel edge length is: ' num2str(sum(SkelFiner.SegStats.Lengths)/size(SkelFiner.FilStats.aEdges,1))]); 
end
end

