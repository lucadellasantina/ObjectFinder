%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2019 Luca Della Santina
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
ColocAuto.Source        = srcDots.Name;
ColocAuto.Fish1         = NN.Name;

AutoColocAnalyzingFlag                      = ones([1,numel(srcDots.Vox)], 'uint8');
ColocAuto.ListDotIDsManuallyColocAnalyzed   = find(AutoColocAnalyzingFlag == 1);
ColocAuto.TotalNumsrcDotsManuallyColocAnalyzed = length(ColocAuto.ListDotIDsManuallyColocAnalyzed);
ColocAuto.ColocFlag                         = zeros([1,ColocAuto.TotalNumsrcDotsManuallyColocAnalyzed], 'uint8');

% Trasverse each valid object and check if Nearest Neighbor is 
% overlappedthe above the voxel and percent thresholds
for i = 1:numel(srcDots.Vox)
    if ~srcDots.Filter.passF(i)
        ColocAuto.ColocFlag(i) = 3; % Invalid dot (filter==0)
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
            ColocAuto.ColocFlag(i) = 2; % Not Colocalized
            continue
        end
    end
    
    % Assign colocalization to objects overlapping more than thresholds
    if (NN.VoxOverlap(i) >= NumVoxOverlap) && (NN.VoxOverlapPerc(i) >= NumPercOverlap) && (NN.Dist(i) <= WithinDist)
        ColocAuto.ColocFlag(i) = 1; % Colocalized
    else
        ColocAuto.ColocFlag(i) = 2; % Not Colocalized
    end
end

ColocAuto.NumsrcDotsColoc      = length(find(ColocAuto.ColocFlag == 1));
ColocAuto.NumsrcDotsNonColoc   = length(find(ColocAuto.ColocFlag == 2));
ColocAuto.NumFalsesrcDots      = length(find(ColocAuto.ColocFlag == 3));
ColocAuto.ColocRate         = ColocAuto.NumsrcDotsColoc/(ColocAuto.NumsrcDotsColoc+ColocAuto.NumsrcDotsNonColoc);
ColocAuto.FalseDotRate      = ColocAuto.NumFalsesrcDots/(ColocAuto.NumsrcDotsColoc+ColocAuto.NumsrcDotsNonColoc+ColocAuto.NumFalsesrcDots);
ColocAuto.ColocRateInclugingFalsesrcDots = ColocAuto.NumsrcDotsColoc/(ColocAuto.NumsrcDotsColoc+ColocAuto.NumsrcDotsNonColoc+ColocAuto.NumFalsesrcDots);
ColocAuto.Method            = 'AutoNN';
ColocAuto.NumVoxOverlap     = NumVoxOverlap;
ColocAuto.NumPercOverlap    = NumPercOverlap;
end