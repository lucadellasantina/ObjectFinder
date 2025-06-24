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

function [SortedObjNames, SortedObjUIDs] = listObjects(folder)
%% List available object names and UIDs
switch nargin
    case 0, folder = pwd;
end

ObjNames = {};
ObjUIDs  = {};

files = dir([folder filesep 'objects' filesep '*.mat']);
for d = 1:numel(files)
    load([folder filesep 'objects' filesep files(d).name],'Name', 'UID');
    if isempty(ObjNames)
        ObjNames = {Name};
        ObjUIDs  = {UID};
    else
        ObjNames{end+1} = Name; %#ok
        ObjUIDs{end+1}  = UID;  %#ok
    end
end

[SortedObjNames, idx] = sort(ObjNames);
SortedObjUIDs = ObjUIDs(idx);
end