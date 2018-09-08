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
function Dots = fitSphere(Dots, Settings)
%% Find mean number of faces for perfect reference sphere
% changed from 11*11*11 to 31*31*31 because I do 0.025um xy 0.2um z for the 
% finest image of CtBP2 puncta (so 24 times more possible dot volume 
% compared to 0.103um xy 0.3um z) 6/25/2010

tic;
fprintf('Calculating sphericity of each object ... ');
TSphere           = zeros(31,31,31);    % Create a matrix to hold the sphere pixels
TSphere2          = zeros(33,33,33);    % Create a slightly bigger sphere to check in the for loop +-1 pixels away from the perimeter 
TSphere(16,16,16) = 1;                  % Place 1 in the center point of the sphere
Tdists            = bwdist(TSphere);    % Record the distances of each point from the center of the sphere
Tvol              = zeros(1,160);       % Tvol(d) stores the number of voxels within the distance of d/10 from the center voxel
meanFaces         = zeros(1,160);       % Initialize the meanFaces vector

for d=1:160                             % If you go >160, the sphere tries to get voxels outside the 31*31*31 3D matrix.
    Near          = find(Tdists<(d/10));% Near are tje pixels within d/10 distance from center. Therefore, for distances d=1:10 only the center point will be identified, then d=11 will identify 6 more voxels around the center voxel.
    Tvol(d)       = size(Near,1);       % Tvol(d) will be the number of voxels within the distance of d/10 from the center voxel
    TSphere(Near) = 1;                  % Fill voxels of the current sphere with ones
    Tperim        = bwperim(TSphere,6); % Fill only pixels on the perimether of the sphere
    NearPerim     = find(Tperim);       % Store voxel number corresponding to perimeter
    FaceCount     = 0;
    [NearPerimY, NearPerimX, NearPerimZ] = ind2sub(size(TSphere), NearPerim); % Convert voxel numbers into y-x-z coordinates for the perimeter

    
    % Explore each voxel at the perimeter, if there is no sphere in the
    % of the perimeter+-1pixel, then increase FaceCount as the real sphere 
    % is a smaller/bigger approximation of this ideal one drawn as flat face.
    % If the sphere ends exactly on the perimeter then numel(FaceCount) == numel(NearPerim)
    
    % Create a slightly bigger sphere to check in the for loop +-1 pixels 
    % away from the perimeter (+0-2 pixels from TSphere2 coordinates)
    TSphere2(2:end-1,2:end-1,2:end-1) = TSphere; 
    
    for n = 1:length(NearPerim) 
        if TSphere2(NearPerimY(n), NearPerimX(n)+1,NearPerimZ(n)+1) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+2, NearPerimX(n)+1,NearPerimZ(n)+1) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+1, NearPerimX(n),NearPerimZ(n)+1) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+1, NearPerimX(n)+2,NearPerimZ(n)+1) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+1, NearPerimX(n)+1,NearPerimZ(n)) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+1, NearPerimX(n)+1,NearPerimZ(n)+2) == 0
            FaceCount = FaceCount+1;
        end
    end
    meanFaces(d)=FaceCount/Tvol(d);  % Number of faces of the sphere of that radius (d) divided by its volume.
end

c = 0;
for v = 1 : max(Tvol)
    if ~isempty(find(Tvol==v, 1))
        c = c+1;
        tvol(c) = v; % tvol will remove redundancy in Tvol, so tvol would be 1, 7, ...
        % convert volume to meanfaces        
        v2f(c) = meanFaces(find(Tvol==v,1)); % find(Tvol==v,1) will take only the 1st one among all Tvol==v, so again removing redundancy in meanFaces
    end
end
RoundFaces = interp1(tvol,v2f,1:max(tvol)); 

%plot(1:max(tvol), RoundFaces, 'o');
%ylabel('Round faces');
%xlabel('tvol = number of voxels within the distance of d/10 from the center voxel');

%% Calculate shape properties for each object
for i = 1:Dots.Num
    % Step-1: Calculate reference distances of each dot along longest axes
    Zscaling= Settings.ImInfo.zum / Settings.ImInfo.xyum;
    Cent    = Dots.Pos(i,:);            % Position of the dot's center
    Vox     = Dots.Vox(i).Pos;          % Position of each voxel of this dot
    Dist    = dist2(Vox,Cent,Zscaling); % Distance of each voxel from center
    MeanD   = max(1,mean(Dist));        % Average distance from center
    VoxN    = Vox/MeanD;                % Distance of each voxel from center
    
    if size(Vox,1) < 4
        % If volume < 4 voxels, PCA cannot calculate 3 variance components
        
        Dots.Shape.Var(i,:)     = [0;0;0];      % Variance (voxel distance) along three PCA axes
        Dots.Shape.SumVar(i)    = 0;            % Sum of distances along the three main axis
        Dots.Shape.Oblong(i)    = 0;            % Ratio of variances between 2nd longest and longest axes, =1 if perfectly round, <1 if not round
    else
        [~, ~, latent]          = pca(VoxN);    % PCA analysis on normalized distances
        Dots.Shape.Var(i,:)     = latent;       % Longest distance from center along the three axis
        Dots.Shape.SumVar(i)    = sum(latent);  % Sum of distances along three axis
        Dots.Shape.Oblong(i)    = mean([latent(2)/latent(1), latent(3)/latent(1)]); % Average longest distance on the 2nd and 3rd longest axis compared to the longest distance == 1 if perfectly spherical or cubic
    end
    
    % Step-2: find surface area for each object
    % Faces for a given voxel within a punctum will be 0 to 6, meaning the
    % numbmer of voxels in 6-connectivity neighbors outside the punctum
    
    for v = 1 : size(Dots.Vox(i).Pos,1)
        Conn                 = dist2(Dots.Vox(i).Pos, Dots.Vox(i).Pos(v,:), Zscaling);
        Dots.Vox(i).Faces(v) = 6-sum(Conn==1);
    end
    Dots.Shape.meanFaces(i)  = mean(Dots.Vox(i).Faces);
    Dots.Shape.Smoothness(i) = Dots.Shape.meanFaces(i) / RoundFaces(Dots.Vol(i)); % Number of faces of the object compared to a sphere
end

%% Calculate 3D principal axis length of the fitting ellipsoid to objects
Dots.Shape.PrincipalAxisLen = zeros(size(Dots.Pos));
for i= 1:Dots.Num
    VoxPos = Dots.Vox(i).Pos;

    % Move the coordinates origin of current object voxels back to (1,1,1)
    VoxPosYMin = min(VoxPos(:,1));
    VoxPosYMax = max(VoxPos(:,1));
    VoxPosXMin = min(VoxPos(:,2));
    VoxPosXMax = max(VoxPos(:,2));
    VoxPosZMin = min(VoxPos(:,3));
    VoxPosZMax = max(VoxPos(:,3));

    VoxPos(:,1) = VoxPos(:,1) - VoxPosYMin +1;
    VoxPos(:,2) = VoxPos(:,2) - VoxPosXMin +1;
    VoxPos(:,3) = VoxPos(:,3) - VoxPosZMin +1;

    VoxPosYMax = VoxPosYMax - VoxPosYMin +1;
    VoxPosXMax = VoxPosXMax - VoxPosXMin +1;
    VoxPosZMax = VoxPosZMax - VoxPosZMin +1;

    % Create a binary mask of current object
    Iobject = zeros(VoxPosYMax, VoxPosXMax, VoxPosZMax, 'logical');
    for j = 1:size(VoxPos, 1)
        Iobject(VoxPos(j,1), VoxPos(j,2), VoxPos(j,3)) = 1;
    end
    
    PrincipalAxisLength = table2array(regionprops3(Iobject, 'PrincipalAxisLength'));
    Dots.Shape.PrincipalAxisLen(i,:) = PrincipalAxisLength(1,:);
end
fprintf(['DONE in ' num2str(toc) ' seconds \n']);
end

function[d] = dist2(A, B, Zscaling)
    % Finds distance between two vectors in form A (n,3,n) and B (1,3)
    %
    % Zscaling: multiplication factor if Z resolution different than XY
    % Zscaling =1 if same XYZ resolution
    % Zscaling = 2 if Z voxel size  = twice XY voxels size
    
    A2                  = zeros(size(A,1),3,size(A,3));
    B2                  = zeros(size(B,1),3);
    A2(:,1:size(A,2),:) = A;
    B2(:,1:size(B,2))   = B;
    A                   = A2;
    B                   = B2;
    d = sqrt((A(:,1,:)-B(1)).^2 + (A(:,2,:)-B(2)).^2 + ((A(:,3,:)-B(3)) * Zscaling).^2);
end