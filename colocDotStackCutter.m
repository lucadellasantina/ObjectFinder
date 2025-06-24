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
function ImStkCut = colocDotStackCutter(ImStk, Dots, DotNum, NumMargins, NumVoxs)

VoxPos = [];
for dot = 1:length(DotNum) %you can enter multiple dots, useful when you want to see the grouping of two dots, or colocalization of two dots.
    VoxPos = [VoxPos; Dots.Vox(DotNum(dot)).Pos];
end

VoxPosYMin = min(VoxPos(:,1));
VoxPosYMax = max(VoxPos(:,1));
VoxPosYMid = round((VoxPosYMin+VoxPosYMax)/2);
VoxPosXMin = min(VoxPos(:,2));
VoxPosXMax = max(VoxPos(:,2));
VoxPosXMid = round((VoxPosXMin+VoxPosXMax)/2);
VoxPosZMin = min(VoxPos(:,3));
VoxPosZMax = max(VoxPos(:,3));
VoxPosZMid = round((VoxPosZMin+VoxPosZMax)/2);

ImSize = size(ImStk);

%you can cut image stack (ImStk) around the dot(s) using Margins around the
%dot contour (NumMargins must be 3-element vector with y, x and z margins. 
%If this way is not used, NumMargins must be []. Or, use simply the number 
%of voxels to be cut (NumVoxs must be 3-element vector with y, x and z vox
%num. If this way is not used, NumVoxs must be []).
if ~isempty(NumMargins)
    ImStkCuty1 = max(VoxPosYMin-NumMargins(1), 1);
    ImStkCuty2 = min(VoxPosYMax+NumMargins(1), ImSize(1));
    ImStkCutx1 = max(VoxPosXMin-NumMargins(2), 1);
    ImStkCutx2 = min(VoxPosXMax+NumMargins(2), ImSize(2));
    ImStkCutz1 = max(VoxPosZMin-NumMargins(3), 1);
    ImStkCutz2 = min(VoxPosZMax+NumMargins(3), ImSize(3));
elseif ~isempty(NumVoxs)
    ImStkCuty1 = max(VoxPosYMid-round(NumVoxs(1)/2), 1);
    ImStkCuty2 = min(VoxPosYMid-round(NumVoxs(1)/2)+NumVoxs(1)-1, ImSize(1));
    ImStkCutx1 = max(VoxPosXMid-round(NumVoxs(2)/2), 1);
    ImStkCutx2 = min(VoxPosXMid-round(NumVoxs(2)/2)+NumVoxs(2)-1, ImSize(2));
    ImStkCutz1 = max(VoxPosZMid-round(NumVoxs(3)/2), 1);
    ImStkCutz2 = min(VoxPosZMid-round(NumVoxs(3)/2)+NumVoxs(3)-1, ImSize(3));
else
    disp('Provide NumMargins or NumVoxs');
end

ImStkCut = ImStk(ImStkCuty1:ImStkCuty2, ImStkCutx1:ImStkCutx2, ImStkCutz1:ImStkCutz2);
