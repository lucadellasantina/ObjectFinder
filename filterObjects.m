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
function[Filter] = filterObjects(Settings, Dots, FilterOpts)
% Filter objects according to FilterOpts
Filter.FilterOpts = FilterOpts;

% Apply Exclusion Criteria to Puncta
pass = ones(1,Dots.Num); % Initialize vector of passing objects

% added the following if-end to remove dots facing outside the mask or image. 1/14/2010 HO
if FilterOpts.EdgeDotCut
    load([Settings.TPN 'Mask.mat'], 'Mask');
    Mask = bwperim(uint8(Mask), 6); % this operation will leave mask voxels facing 0 or outside the image as 1, and change the other mask voxels to 0.
    VoxIDMap = zeros(Dots.ImSize);
    for i=1:Dots.Num
        VoxIDMap(Dots.Vox(i).Ind)=i;
    end
    EdgeVoxIDMap = Mask.*VoxIDMap; %contour voxels located at the edge of the mask or image remains, and shows the dot ID#, other voxels are all 0.
    clear D;
    EdgeDotIDs = unique(EdgeVoxIDMap);
    if EdgeDotIDs(1) == 0
        EdgeDotIDs(1)=[];
    end
    NonEdgeDots = ones(1,Dots.Num);
    NonEdgeDots(1, EdgeDotIDs)=0;
    save([Settings.TPN 'data' filesep 'NonEdgeDots.mat'],'NonEdgeDots');
    pass = pass & NonEdgeDots; % Exclude edge dots
end

% SingleZDotCut: exclude dots whose voxels spread only in one Z plane.
% This is not necessary for PSD95 dots but sometimes works well with
% CtBP2 dots which include very dim noisy dots and speckling noise.
if FilterOpts.SingleZDotCut
    zVoxNum = zeros(1,Dots.Num);
    for i=1:Dots.Num
        zVoxNum(i) = length(unique(Dots.Vox(i).Pos(:,3)));
    end
    SingleZDotIDs = zVoxNum==1;
    NonSingleZDots = ones(1,Dots.Num);
    NonSingleZDots(1, SingleZDotIDs)=0;
    save([Settings.TPN 'data' filesep 'NonSingleZDots.mat'],'NonSingleZDots');
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
    save([Settings.TPN 'data' filesep 'xyStableDots.mat'],'xyStableDots');
    pass = pass & xyStableDots;                                     % Trim moving dots away
    fprintf('Dots excluded because moving during aquisition: %u\n', numel(xyStableDots) - numel(find(xyStableDots)));
end

% User-defined thresholds for ITMax, Vol and MeanBright
if isfield(FilterOpts, 'Thresholds')
    threshpass = Dots.ITMax >= FilterOpts.Thresholds.ITMax;
    threshpass = threshpass & (Dots.Vol >= FilterOpts.Thresholds.Vol);
    threshpass = threshpass & (Dots.MeanBright >= FilterOpts.Thresholds.MeanBright);
    if isfield(FilterOpts.Thresholds, 'Oblong')
        threshpass = threshpass & (Dots.Shape.Oblong >= FilterOpts.Thresholds.Oblong);
    end
    if isfield(FilterOpts.Thresholds, 'PrincipalAxisLen')
        threshpass = threshpass & (Dots.Shape.PrincipalAxisLen(:,1)' >= FilterOpts.Thresholds.PrincipalAxisLen);
    end    
    pass = pass & threshpass; % Exclude objects not passing the thresholds
end

Filter.passF=pass';
disp(['Number of objects initially detected: ' num2str(Dots.Num)]);
disp(['Number of objects validated after filtering: ' num2str(length(find(Filter.passF)))]);
end