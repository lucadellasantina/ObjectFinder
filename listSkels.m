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

function [SortedSkelNames, SortedSkelUIDs] = listSkels(folder)
%% List available skeleton names and UIDs
switch nargin
    case 0, folder = pwd;
end

SkelNames = {};
SkelUIDs  = {};

files = dir([folder filesep 'skeletons' filesep '*.mat']);
for f = 1:numel(files)
    load([folder filesep 'skeletons' filesep files(f).name],'Name', 'UID');
    if isnumeric(Name)
        Name = ['Filament ' num2str(Name)];       
    end
    if isempty(SkelNames)
        SkelNames = {Name};
        SkelUIDs  = {UID};
    else
        SkelNames{end+1} = Name; %#ok
        SkelUIDs{end+1}  = UID;  %#ok
    end
end

[SortedSkelNames, idx] = sort(SkelNames);
SortedSkelUIDs = SkelUIDs(idx);
end