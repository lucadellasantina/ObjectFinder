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

function Settings = loadSettings(FieldNames)
%% Load objects matching ObjName
if nargin < 1
    FieldNames = {};
end

Settings = [];
if ~exist([pwd filesep 'Settings.mat'],'file')
    return
end

if isempty(FieldNames)
    Settings = load([pwd filesep 'Settings.mat']);
    if isfield(Settings, 'Settings')
        Settings = Settings.Settings;
    end
else
    Settings = load([pwd filesep 'Settings.mat'], FieldNames{:});
end

end