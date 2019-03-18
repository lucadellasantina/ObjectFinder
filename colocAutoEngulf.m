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
% *Colocalization - Automatic overlap analysis between engulfing/engilfed*
% Required parameters
%    Dots           = Reference engulfing objects
%    DotsEngulfed   = Destination engulfed objects
%    NumVoxOverlap  = Number of overlapping voxels between each objet and
%                     the binary mask to consider the object as colocalized
%    NumPercOverlap = Number of overlapping voxels between each objet and
%                     the binary mask expressed as percentage of Dots size
%                     to consider the object as colocalized

function ColocAuto = colocAutoEngulf(Dots, DotsEngulfed, NumVoxOverlap, NumPercOverlap)
%%
ColocAuto.Source        = Dots.Name;
ColocAuto.Fish1         = DotsEngulfed.Name;

AutoColocAnalyzingFlag                      = ones([1,numel(Dots.Vox)], 'uint8');
ColocAuto.ListDotIDsManuallyColocAnalyzed   = find(AutoColocAnalyzingFlag == 1);
ColocAuto.TotalNumDotsManuallyColocAnalyzed = length(ColocAuto.ListDotIDsManuallyColocAnalyzed);
ColocAuto.ColocFlag                         = zeros([1,ColocAuto.TotalNumDotsManuallyColocAnalyzed], 'uint8');

% Trasverse each reference object and count how many objects are engulfed
% *IMPORTANT*: ColocAuto here stores the absolute number DotsEngifled that 
% each reference object in Dots is engulfing more than passed threshold

for idx_src = 1:numel(Dots.Vox)
    ColocAuto.ColocFlag(idx_src) = 0; % Invalid dot (filter==0)
    if ~Dots.Filter.passF(idx_src), continue; end
   
    for idx_dst = 1:numel(DotsEngulfed.Vox)
        if ~DotsEngulfed.Filter.passF(idx_dst), continue; end
        
        VoxOverlap     = numel(intersect(Dots.Vox(idx_src).Ind, DotsEngulfed.Vox(idx_dst).Ind));
        VoxOverlapPerc = 100 * VoxOverlap / DotsEngulfed.Vol(idx_dst); % Store voxel overlap as percent of source object volume
        
        if (VoxOverlap >= NumVoxOverlap) && (VoxOverlapPerc >= NumPercOverlap)
            ColocAuto.ColocFlag(idx_src) = ColocAuto.ColocFlag(idx_src) + 1; % Add one more engulfed
        end
    end
end

ColocAuto.NumDotsColoc      = length(find(ColocAuto.ColocFlag > 0));
ColocAuto.NumDotsNonColoc   = length(find(ColocAuto.ColocFlag == 0));
ColocAuto.NumFalseDots      = 0;
ColocAuto.ColocRate         = ColocAuto.NumDotsColoc/(ColocAuto.NumDotsColoc+ColocAuto.NumDotsNonColoc);
ColocAuto.FalseDotRate      = ColocAuto.NumFalseDots/(ColocAuto.NumDotsColoc+ColocAuto.NumDotsNonColoc+ColocAuto.NumFalseDots);
ColocAuto.ColocRateInclugingFalseDots = ColocAuto.NumDotsColoc/(ColocAuto.NumDotsColoc+ColocAuto.NumDotsNonColoc+ColocAuto.NumFalseDots);
ColocAuto.Method            = 'AutoEngulf';
ColocAuto.NumVoxOverlap     = NumVoxOverlap;
ColocAuto.NumPercOverlap    = NumPercOverlap;
end