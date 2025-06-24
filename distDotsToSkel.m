%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2025 Luca Della Santina
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
function Dots = distDotsToSkel(Dots, Skel, Settings)
SkelYXZ = [Skel.FilStats.aXYZ(:,2), Skel.FilStats.aXYZ(:,1), Skel.FilStats.aXYZ(:,3)];

xyum            = Settings.ImInfo.xyum;
zum             = Settings.ImInfo.zum;
DotPosYXZ       = [Dots.Pos(:,1)*xyum, Dots.Pos(:,2)*xyum, Dots.Pos(:,3)*zum];
minDot2SkelDist = zeros(1, Dots.Num);
minDot2SkelIDs  = zeros(1, Dots.Num);

for i = 1:Dots.Num
    Dist = dist2(SkelYXZ,DotPosYXZ(i,:));
    [minDot2SkelDist(i), minDot2SkelIDs(i)] = min(Dist);
end

Dots.Skel.ClosestSkelIDs    = minDot2SkelIDs;
Dots.Skel.ClosestSkelDist   = minDot2SkelDist;
end

function[d]=dist2(A,B)
%finds distance between two vectors in form A (n,3,n) and B (1,3)
A2 = zeros(size(A,1),3,size(A,3));
B2 = zeros(size(B,1),3);
A2(:,1:size(A,2),:) = A;
B2(:,1:size(B,2)) = B;
A = A2;
B = B2;
d = sqrt((A(:,1,:)-B(1)).^2 + (A(:,2,:)-B(2)).^2 + (A(:,3,:)-B(3)).^2);
end