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
% *Colocalization - Automatic analysis of overlap against a binary mask*
% Required parameters
%    Dots = list of recognized objects
%    Filter = boolean list of which objects in Dots are validated
%    Colo = XYZ matrix of the colocalizing binary mask
%    FileName = Name of the colocalizing binary mask file
%    NumVoxOverlap = Number of overlapping voxels between each objet and
%                    the binary mask to consider the object as colocalized
%

function ColocAuto = colocAutoMask(Dots, Filter, Colo, FileName, NumVoxOverlap, NumPercOverlap)
%%
Grouped = getFilteredObjects(Dots, Filter);
[~, fName, ~] = fileparts(FileName);
ColocAuto.Source        = Dots.Name;
ColocAuto.Fish1         = fName;

AutoColocAnalyzingFlag  = ones([1,numel(Grouped.Vox)], 'uint8');
ColocAuto.ListDotIDsManuallyColocAnalyzed = find(AutoColocAnalyzingFlag == 1);
ColocAuto.TotalNumDotsManuallyColocAnalyzed = length(ColocAuto.ListDotIDsManuallyColocAnalyzed);
ColocAuto.ColocFlag     = zeros([1,ColocAuto.TotalNumDotsManuallyColocAnalyzed], 'uint8');

for i=1:numel(Grouped.Vox)    
    % Trasverse each valid objects and check if the mask is overlapping
    VoxOverlap = numel(find(Colo(Grouped.Vox(i).Ind))); %one liner using indexes
    
    % Define also overlap as percent of total object size
    PercOverlap = 100 * VoxOverlap / Grouped.Vol(i); 
    
    if (VoxOverlap >= NumVoxOverlap) && (PercOverlap >= NumPercOverlap)
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
ColocAuto.Method            = 'AutoMask';
ColocAuto.NumVoxOverlap     = NumVoxOverlap;
ColocAuto.NumPercOverlap    = NumPercOverlap;

end