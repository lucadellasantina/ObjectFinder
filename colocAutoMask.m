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
ColocAuto.Ref = srcDots.Name;
ColocAuto.Dst = fName;
ColocAuto.Flag = zeros([1,numel(srcDots.Vox)], 'uint8');

ColocAuto.Settings.Method = 'AutoMask';
ColocAuto.Settings.NumVoxOverlap = NumVoxOverlap;
ColocAuto.Settings.NumPercOverlap = NumPercOverlap;
ColocAuto.Settings.DistanceWithin = inf;
ColocAuto.Settings.CentroidOverlap = CenterMustOverlap;
ColocAuto.Settings.RotationAngle = 0;

for i= 1:numel(srcDots.Vox)
    if ~srcDots.Filter.passF(i)
        ColocAuto.Flag(i) = 3; % Invalid dot (filter==0)
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
            ColocAuto.Flag(i) = 2; % Not Colocalized
            continue
        end
    end
    
    % Trasverse each valid objects and check if the mask is overlapping
    VoxOverlap = numel(find(Colo(srcDots.Vox(i).Ind))); %one liner using indexes
    
    % Define also overlap as percent of total object size
    PercOverlap = 100 * VoxOverlap / srcDots.Vol(i);
    
    if (VoxOverlap >= NumVoxOverlap) && (PercOverlap >= NumPercOverlap)
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