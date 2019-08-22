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
function [Filter] = filterObjects(Dots, FilterOpts)
% Filter objects according to FilterOpts
Filter.FilterOpts = FilterOpts;

% Apply Exclusion Criteria to Puncta
pass = ones(1,Dots.Num); % Initialize vector of passing objects

% Remove dots facing outside the mask or image
if FilterOpts.EdgeDotCut
    if isfield(Dots.Settings.ImInfo, 'MaskChName') && ~isempty(Dots.Settings.ImInfo.MaskChName)
        Mask = loadImage(Dots.Settings.ImInfo.MaskChName);
    end
    
    Mask = bwperim(uint8(Mask), 6); % this operation will leave mask voxels facing 0 or outside the image as 1, and change the other mask voxels to 0.
    VoxIDMap = zeros(Dots.ImSize);
    for i=1:Dots.Num
        VoxIDMap(Dots.Vox(i).Ind)=i;
    end
    
    EdgeVoxIDMap = Mask.*VoxIDMap; %contour voxels located at the edge of the mask or image remains, and shows the dot ID#, other voxels are all 0.
    EdgeDotIDs = unique(EdgeVoxIDMap);
    if EdgeDotIDs(1) == 0
        EdgeDotIDs(1)=[];
    end
    NonEdgeDots = ones(1,Dots.Num);
    NonEdgeDots(1, EdgeDotIDs)=0;
    pass = pass & NonEdgeDots; % Exclude edge dots
end

% SingleZDotCut: exclude dots whose voxels spread only in one Z plane.
if FilterOpts.SingleZDotCut
    zVoxNum = zeros(1,Dots.Num);
    for i=1:Dots.Num
        zVoxNum(i) = length(unique(Dots.Vox(i).Pos(:,3)));
    end
    SingleZDotIDs = zVoxNum==1;
    NonSingleZDots = ones(1,Dots.Num);
    NonSingleZDots(1, SingleZDotIDs)=0;
    pass = pass & NonSingleZDots; % Exclude single Z dots
end

% Remove Dots that whose centroid is moving along Z stack
if FilterOpts.xyStableDots
    xyStableDots = ones(1,Dots.Num);                                %Store Dots passing the test
    for i=1:Dots.Num
        zPlanes = sort(unique(Dots.Vox(i).Pos(:,3)));               % Find unique z planes and store value of their Z position
        xyPos = zeros(numel(zPlanes), 2);                           % Store here XY position of centroids for each Z plane
        
        for j=1:numel(zPlanes)                                      % For each z plane
            zPosMask = Dots.Vox(i).Pos(:,3) == zPlanes(j);          % Find voxels belonging to the current Z plane
            brightMask = Dots.Vox(i).RawBright == max(Dots.Vox(i).RawBright(zPosMask)); % Find brightest voxels
            xyPos(j,:) = [mean(Dots.Vox(i).Pos(zPosMask & brightMask,1)),...
                mean(Dots.Vox(i).Pos(zPosMask & brightMask,2))];    % Store position of centroid
        end
        %HO interpretation, removing dots that are moving either x or y direction
        %with its std more than a threshold number of voxels, here set to 2.
        %10/18/2011
        if (std(xyPos(:,1))>2) || (std(xyPos(:,2))>2)                % Test centroids are moving for more than 2 st.dev on XY plane
            xyStableDots(i)=0;                                      % False if not aligned
        end
    end
    pass = pass & xyStableDots;                                     % Trim moving dots away
    fprintf('Dots excluded because moving during aquisition: %u\n', numel(xyStableDots) - numel(find(xyStableDots)));
end

% Apply user-defined thresholds for each parameter
if isfield(FilterOpts, 'Thresholds')
    if FilterOpts.Thresholds.ITMaxDir == 1
        threshpass = Dots.ITMax >= FilterOpts.Thresholds.ITMax;
    else
        threshpass = Dots.ITMax <= FilterOpts.Thresholds.ITMax;
    end
    
    if FilterOpts.Thresholds.VolDir == 1
        threshpass = threshpass & (Dots.Vol >= FilterOpts.Thresholds.Vol);
    else
        threshpass = threshpass & (Dots.Vol <= FilterOpts.Thresholds.Vol);
    end

    if FilterOpts.Thresholds.MeanBrightDir == 1
        threshpass = threshpass & (Dots.MeanBright >= FilterOpts.Thresholds.MeanBright);
    else
        threshpass = threshpass & (Dots.MeanBright <= FilterOpts.Thresholds.MeanBright);
    end
    
    if FilterOpts.Thresholds.MeanBrightDir == 1
        threshpass = threshpass & (Dots.MeanBright >= FilterOpts.Thresholds.MeanBright);
    else
        threshpass = threshpass & (Dots.MeanBright <= FilterOpts.Thresholds.MeanBright);
    end
    
    if isfield(FilterOpts.Thresholds, 'Oblong') && isfield(Dots.Shape, 'Oblong')
        if FilterOpts.Thresholds.OblongDir == 1
            threshpass = threshpass & (Dots.Shape.Oblong >= FilterOpts.Thresholds.Oblong);
        else
            threshpass = threshpass & (Dots.Shape.Oblong <= FilterOpts.Thresholds.Oblong);
        end
    end
    
    if isfield(FilterOpts.Thresholds, 'PrincipalAxisLen') && isfield(Dots.Shape, 'PrincipalAxisLen')
        if FilterOpts.Thresholds.PrincipalAxisLenhDir == 1
            threshpass = threshpass & (Dots.Shape.PrincipalAxisLen(:,1)' >= FilterOpts.Thresholds.PrincipalAxisLen);
        else
            threshpass = threshpass & (Dots.Shape.PrincipalAxisLen(:,1)' <= FilterOpts.Thresholds.PrincipalAxisLen);
        end
    end 
    
    if isfield(FilterOpts.Thresholds, 'Zposition')
        if FilterOpts.Thresholds.ZpositionDir == 1
            threshpass = threshpass & (Dots.Pos(:,3) >= FilterOpts.Thresholds.Zposition);
        else
            threshpass = threshpass & (Dots.Pos(:,3) <= FilterOpts.Thresholds.Zposition);
        end
    end
    
    pass = pass & threshpass; % Exclude objects not passing all thresholds
end

if isfield(FilterOpts, 'Thresholds2')
    if FilterOpts.Thresholds2.ITMaxDir == 1
        threshpass = Dots.ITMax >= FilterOpts.Thresholds2.ITMax;
    else
        threshpass = Dots.ITMax <= FilterOpts.Thresholds2.ITMax;
    end
    
    if FilterOpts.Thresholds2.VolDir == 1
        threshpass = threshpass & (Dots.Vol >= FilterOpts.Thresholds2.Vol);
    else
        threshpass = threshpass & (Dots.Vol <= FilterOpts.Thresholds2.Vol);
    end
    
    if FilterOpts.Thresholds2.MeanBrightDir == 1
        threshpass = threshpass & (Dots.MeanBright >= FilterOpts.Thresholds2.MeanBright);
    else
        threshpass = threshpass & (Dots.MeanBright <= FilterOpts.Thresholds2.MeanBright);
    end
    
    if isfield(FilterOpts.Thresholds2, 'Oblong') && isfield(Dots.Shape, 'Oblong')
        if FilterOpts.Thresholds2.OblongDir == 1
            threshpass = threshpass & (Dots.Shape.Oblong >= FilterOpts.Thresholds2.Oblong);
        else
            threshpass = threshpass & (Dots.Shape.Oblong <= FilterOpts.Thresholds2.Oblong);
        end
    end
    
    if isfield(FilterOpts.Thresholds2, 'PrincipalAxisLen') && isfield(Dots.Shape, 'PrincipalAxisLen')
        if FilterOpts.Thresholds2.PrincipalAxisLenhDir == 1
            threshpass = threshpass & (Dots.Shape.PrincipalAxisLen(:,1)' >= FilterOpts.Thresholds2.PrincipalAxisLen);
        else
            threshpass = threshpass & (Dots.Shape.PrincipalAxisLen(:,1)' <= FilterOpts.Thresholds2.PrincipalAxisLen);
        end
    end
    
    if isfield(FilterOpts.Thresholds2, 'Zposition')
        if FilterOpts.Thresholds2.ZpositionDir == 1
            threshpass = threshpass & (Dots.Pos(:,3) >= FilterOpts.Thresholds2.Zposition);
        else
            threshpass = threshpass & (Dots.Pos(:,3) <= FilterOpts.Thresholds2.Zposition);
        end
    end
 
    
    pass = pass & threshpass; % Exclude objects not passing all thresholds
end

Filter.passF=pass';

disp(['Number of objects initially detected: ' num2str(Dots.Num)]);
disp(['Number of objects validated after filtering: ' num2str(length(find(Filter.passF)))]);
end