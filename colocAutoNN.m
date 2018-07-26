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
% *Colocalization - Automatic overlap analysis between nearest neighbors*
% Required parameters
%    Dots = list of recognized objects
%    NN = Nearest neighbors of Dots to analyze
%    NumVoxOverlap =  Number of overlapping voxels between each objet and
%                     the binary mask to consider the object as colocalized
%    NumPercOverlap = Number of overlapping voxels between each objet and
%                     the binary mask expressed as percentage of Dots size
%                     to consider the object as colocalized

function ColocAuto = colocAutoNN(Dots, NN, NumVoxOverlap, NumPercOverlap)
%%
Grouped             = getFilteredObjects(Dots, Dots.Filter);
ColocAuto.Source    = Dots.Name;
ColocAuto.Fish1     = NN.Name;
VoxOverlap          = NN.VoxOverlap(find(Dots.Filter.passF));
VoxOverlapPerc      = NN.VoxOverlapPerc(find(Dots.Filter.passF));

AutoColocAnalyzingFlag                      = ones([1,numel(Grouped.Vox)], 'uint8');
ColocAuto.ListDotIDsManuallyColocAnalyzed   = find(AutoColocAnalyzingFlag == 1);
ColocAuto.TotalNumDotsManuallyColocAnalyzed = length(ColocAuto.ListDotIDsManuallyColocAnalyzed);
ColocAuto.ColocFlag                         = zeros([1,ColocAuto.TotalNumDotsManuallyColocAnalyzed], 'uint8');

% Trasverse each valid object and check if Nearest Neighbor is 
% overlappedthe above the voxel and percent thresholds
for i=1:numel(Grouped.Vox)
    if (VoxOverlap(i) >= NumVoxOverlap) && (VoxOverlapPerc(i) >= NumPercOverlap)
        ColocAuto.ColocFlag(i) = 1; % Colocalized
    else
        ColocAuto.ColocFlag(i) = 2; % Not Colocalized
    end
end

ColocAuto.NumDotsColoc      = length(find(ColocAuto.ColocFlag == 1));
ColocAuto.NumDotsNonColoc   = length(find(ColocAuto.ColocFlag == 2));
ColocAuto.NumFalseDots      = length(find(ColocAuto.ColocFlag == 3));
ColocAuto.ColocRate         = ColocAuto.NumDotsColoc/(ColocAuto.NumDotsColoc+ColocAuto.NumDotsNonColoc);
ColocAuto.FalseDotRate      = ColocAuto.NumFalseDots/(ColocAuto.NumDotsColoc+ColocAuto.NumDotsNonColoc+ColocAuto.NumFalseDots);
ColocAuto.ColocRateInclugingFalseDots = ColocAuto.NumDotsColoc/(ColocAuto.NumDotsColoc+ColocAuto.NumDotsNonColoc+ColocAuto.NumFalseDots);
end