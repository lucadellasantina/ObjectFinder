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
% *Colocalization - Automatic analysis of overlap against a binary mask*
% Required parameters
%    Dots = list of recognized objects
%    Filter = boolean list of which objects in Dots are validated
%    Colo = XYZ matrix of the colocalizing binary mask
%    FileName = Name of the colocalizing binary mask file
%    NumVoxOverlap = Number of overlapping voxels between each objet and
%                    the binary mask to consider the object as colocalized
%

function ColocAuto = colocAutoMask(srcDots, Colo, FileName, NumVoxOverlap, NumPercOverlap, CenterMustOverlap)
%%
[~, fName, ~] = fileparts(FileName);
ColocAuto.Source        = srcDots.Name;
ColocAuto.Fish1         = fName;

AutoColocAnalyzingFlag  = ones([1,numel(srcDots.Vox)], 'uint8');
ColocAuto.ListDotIDsManuallyColocAnalyzed = find(AutoColocAnalyzingFlag == 1);
ColocAuto.TotalNumDotsManuallyColocAnalyzed = length(ColocAuto.ListDotIDsManuallyColocAnalyzed);
ColocAuto.ColocFlag     = zeros([1,ColocAuto.TotalNumDotsManuallyColocAnalyzed], 'uint8');

for i=1:numel(srcDots.Vox)
    if ~srcDots.Filter.passF(i)
        ColocAuto.ColocFlag(i) = 3; % Invalid dot (filter==0)
        continue
    end
    
    if CenterMustOverlap
        % Calculate brightness peak position because srcDots.Pos(i,:) might not
        % be any of the actual pixels listed in srcDots.Vox(i).Pos
        BrightPeakPos = srcDots.Vox(i).Ind(srcDots.Vox(i).RawBright == max(srcDots.Vox(i).RawBright));
        if size(BrightPeakPos,1) > 1
            BrightPeakPos = BrightPeakPos(1,:);
        end
        
        if ~Colo(BrightPeakPos)
            ColocAuto.ColocFlag(i) = 2; % Not Colocalized
            continue
        end
    end
    
    % Trasverse each valid objects and check if the mask is overlapping
    VoxOverlap = numel(find(Colo(srcDots.Vox(i).Ind))); %one liner using indexes
    
    % Define also overlap as percent of total object size
    PercOverlap = 100 * VoxOverlap / srcDots.Vol(i);
    
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