%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2024 Luca Della Santina
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
function[Passing] = getFilteredObjects(Objects, Filter)

% Ensure that filter is a binary mask
Filter.passF = logical(Filter.passF);

Passing.UID         = Objects.UID;
Passing.Name        = Objects.Name;
if isfield(Objects, 'ImSize')
    Passing.ImSize      = Objects.ImSize;
end
Passing.Settings    = Objects.Settings;
Passing.Pos         = Objects.Pos(Filter.passF, :);
Passing.Vox         = Objects.Vox(Filter.passF);
Passing.Vol         = Objects.Vol(Filter.passF);
Passing.ITMax       = Objects.ITMax(Filter.passF);
Passing.ItSum       = Objects.ItSum(Filter.passF);
Passing.MeanBright  = Objects.MeanBright(Filter.passF);
Passing.Density     = Objects.Density;
Passing.NN          = Objects.NN;
Passing.Coloc       = Objects.Coloc;
Passing.Skel        = Objects.Skel;
Passing.Shape       = Objects.Shape;

if isfield(Objects.Shape,'Oblong')
    Passing.Shape.Oblong = Objects.Shape.Oblong(Filter.passF);
end
if isfield(Objects.Shape,'PrincipalAxisLen')
    Passing.Shape.PrincipalAxisLen = Objects.Shape.PrincipalAxisLen(Filter.passF,:);
end
if isfield(Objects.Skel,'Dist2CB')
    Passing.Skel.Dist2CB = Objects.Skel.Dist2CB(Filter.passF,:);
end
if isfield(Objects.Skel,'ClosestSkelIDs')
    Passing.Skel.ClosestSkelIDs = Objects.Skel.ClosestSkelIDs(Filter.passF);
end
if isfield(Objects.Skel,'ClosestSkelDist')
    Passing.Skel.ClosestSkelDist = Objects.Skel.ClosestSkelDist(Filter.passF);
end

Passing.Filter       = Filter;
Passing.Filter.passF = ones(numel(find(Filter.passF)),1);
Passing.Num          = numel(Passing.Filter.passF);

end