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

function Net = loadNetwork(RequestedUID, FieldNames)
%% Load objects matching ObjName
NetFolder = [userpath filesep 'ObjectFinder' filesep 'NeuralNets']; 

if nargin <2
    FieldNames = {};
end

files = dir(NetFolder);         % List the content of /Objects folder
    files = files(~[files.isdir]);  % Keep only files, discard subfolders
    
    for d = 1:numel(files)
        [~, fName, ~] = fileparts(files(d).name);
        if strcmp(fName, RequestedUID)
            if isempty(FieldNames)
                Net = load([NetFolder filesep files(d).name]);
            else
                Net = load([NetFolder filesep files(d).name], FieldNames{:});                
            end
            return;
        end
    end
end