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
function [ImStkCut, VolumePos] = inspectStackCutter(ImStk, Pos, NumVoxs)

ImStkCutx1 = max(Pos(1)-round(NumVoxs(1)/2), 1);
ImStkCutx2 = min(Pos(1)-round(NumVoxs(1)/2)+NumVoxs(1)-1, size(ImStk,1));
ImStkPaddingX = NumVoxs(1) - (ImStkCutx2 - ImStkCutx1 + 1); % Calculate padding if required cut region falls out of image XY size

ImStkCuty1 = max(Pos(2)-round(NumVoxs(2)/2), 1);
ImStkCuty2 = min(Pos(2)-round(NumVoxs(2)/2)+NumVoxs(2)-1, size(ImStk,2));
ImStkPaddingY = NumVoxs(2) - (ImStkCuty2 - ImStkCuty1 + 1); % Calculate padding if required cut region falls out of image XY size

ImStkCutz1 = max(Pos(3)-round(NumVoxs(3)/2), 1);
ImStkCutz2 = min(Pos(3)-round(NumVoxs(3)/2)+NumVoxs(3)-1, size(ImStk,3));
ImStkPaddingZ = NumVoxs(3) - (ImStkCutz2 - ImStkCutz1 + 1); % Calculate padding if required cut region falls out of image Z size

ImStkCut = zeros(NumVoxs(1), NumVoxs(2), ImStkCutz2 - ImStkCutz1 +1);
VolumePos(1,:) = [ImStkCutx1, ImStkCutx2];
VolumePos(2,:) = [ImStkCuty1, ImStkCuty2];
VolumePos(3,:) = [ImStkCutz1, ImStkCutz2];

ImStkCut(ImStkPaddingX+1 : ImStkPaddingX+ImStkCutx2-ImStkCutx1+1, ...
         ImStkPaddingY+1 : ImStkPaddingY+ImStkCuty2-ImStkCuty1+1, ...
         ImStkPaddingZ+1 : ImStkPaddingZ+ImStkCutz2-ImStkCutz1+1) = ...
         ImStk(ImStkCutx1:ImStkCutx2, ImStkCuty1:ImStkCuty2, ImStkCutz1:ImStkCutz2);
end