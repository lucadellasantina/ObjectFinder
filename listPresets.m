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

function [SortedNames, SortedUIDs] = listPresets(folder)
%% List available skeleton names and UIDs
switch nargin
    case 0, folder = [userpath filesep 'ObjectFinder' filesep 'Presets'];
end

Names = {};
UIDs  = {};

files = dir(folder);            % List the content of /Objects folder
files = files(~[files.isdir]);  % Keep only files, discard subfolders
for f = 1:numel(files)
    load([folder filesep files(f).name], 'Name', 'UID');
    if isempty(Names)
        Names = {Name};
        UIDs  = {UID};
    else
        Names{end+1} = Name; %#ok
        UIDs{end+1}  = UID;  %#ok
    end
end

[SortedNames, idx] = sort(Names);
SortedUIDs = UIDs(idx);
end