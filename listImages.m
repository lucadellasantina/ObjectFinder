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

function SortedImgNames = listImages(folder)
%% List available object names and UIDs
switch nargin
    case 0, folder = pwd;
end

files = dir([folder filesep 'I' filesep '*.tif']); % List TIF images in ./I folder
ImgNames = [];
for f = numel(files):-1:1
    ImgNames{f} = files(f).name;
end

if isempty(ImgNames)
    SortedImgNames = [];
else
    SortedImgNames = sort(ImgNames);
end
end