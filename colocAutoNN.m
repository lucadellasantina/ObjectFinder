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
% *Colocalization - Automatic overlap analysis between nearest neighbors*
% Required parameters
%    srcDots = list of recognized objects
%    NN = Nearest neighbors of srcDots to analyze
%    NumVoxOverlap =  Number of overlapping voxels between each objet and
%                     the binary mask to consider the object as colocalized
%    NumPercOverlap = Number of overlapping voxels between each objet and
%                     the binary mask expressed as percentage of srcDots size
%                     to consider the object as colocalized

function ColocAuto = colocAutoNN(srcDots, dstDots, NN, NumVoxOverlap, NumPercOverlap, WithinDist, CenterMustOverlap)
%%
ColocAuto.Ref  = srcDots.Name;
ColocAuto.Dst  = NN.Name;
ColocAuto.Flag = zeros([1,numel(srcDots.Vox)], 'uint8');

ColocAuto.Settings.Method = 'AutoNN';
ColocAuto.Settings.NumVoxOverlap = NumVoxOverlap;
ColocAuto.Settings.NumPercOverlap = NumPercOverlap;
ColocAuto.Settings.DistanceWithin = WithinDist;
ColocAuto.Settings.CentroidOverlap = CenterMustOverlap;
ColocAuto.Settings.RotationAngle = 0;

% Trasverse each valid object and check if Nearest Neighbor is 
% overlappedthe above the voxel and percent thresholds
for i = 1:numel(srcDots.Vox)
    if ~srcDots.Filter.passF(i)
        ColocAuto.Flag(i) = 3; % Invalid dot (filter==0)
        continue
    end
    
    if CenterMustOverlap
        % Calculate brightness peak position because srcDots.Pos(i,:) might not
        % be any of the actual pixels listed in srcDots.Vox(i).Pos
        idx_dst = NN.NeighborIdx(i);
        BrightPeakPos = dstDots.Vox(idx_dst).Ind(dstDots.Vox(idx_dst).RawBright == max(dstDots.Vox(idx_dst).RawBright));
        if size(BrightPeakPos,1) > 1
            BrightPeakPos = BrightPeakPos(1,:);
        end
        
        % Check whether center of NN dstDot is among the voxels of srcDot
        if isempty(find(srcDots.Vox(i).Ind == BrightPeakPos, 1))
            ColocAuto.Flag(i) = 2; % Not Colocalized
            continue
        end
    end
    
    % Assign colocalization to objects overlapping more than thresholds
    if (NN.VoxOverlap(i) >= NumVoxOverlap) && (NN.VoxOverlapPerc(i) >= NumPercOverlap) && (NN.Dist(i) <= WithinDist)
        ColocAuto.Flag(i) = 1; % Colocalized
    else
        ColocAuto.Flag(i) = 2; % Not Colocalized
    end
end

ColocAuto.Results.NumColoc    = length(find(ColocAuto.Flag == 1));
ColocAuto.Results.NumNonColoc = length(find(ColocAuto.Flag == 2));
ColocAuto.Results.NumFalse    = length(find(ColocAuto.Flag == 3));
ColocAuto.Results.ColocRate   = ColocAuto.Results.NumColoc/(ColocAuto.Results.NumColoc+ColocAuto.Results.NumNonColoc);
ColocAuto.Results.FalseRate   = ColocAuto.Results.NumFalse/(ColocAuto.Results.NumColoc+ColocAuto.Results.NumNonColoc+ColocAuto.Results.NumFalse);
end