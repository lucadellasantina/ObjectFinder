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
function[Passing] = getFilteredObjects(Objects, Filter)
Passing.idx = find(Filter.passF);
Passing.Pos = Objects.Pos(Filter.passF, :);
Passing.Vox = Objects.Vox(Filter.passF);
Passing.Vol = Objects.Vol(Filter.passF);
Passing.ITMax = Objects.ITMax(Filter.passF);
Passing.ItSum = Objects.ItSum(Filter.passF);
Passing.MeanBright = Objects.MeanBright(Filter.passF);
if isfield(Objects,'Dist2CB')
    Passing.Dist2CB = Objects.Dist2CB(Filter.passF,:);
end
if isfield(Objects,'ClosestSkelIDs')
    Passing.ClosestSkelIDs = Objects.ClosestSkelIDs(Filter.passF);
end
if isfield(Objects,'ClosestSkelDist')
    Passing.ClosestSkelDist = Objects.ClosestSkelDist(Filter.passF);
end
Passing.ImSize = Objects.ImSize;
end