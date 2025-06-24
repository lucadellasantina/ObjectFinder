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

function tblN = listNetwork
%% List available object names and UIDs
NetFolder = [userpath filesep 'ObjectFinder' filesep 'NeuralNets'];
files = dir([NetFolder filesep '*.mat']);

tblN = repmat(table({'Empty'}, {'Empty'}, {'Empty'}, {'Empty'}, false, {'Empty'}),numel(files),1);
for d = 1:numel(files)
    N = load([NetFolder filesep files(d).name], 'Name', 'Target', 'Type', 'Model', 'Trained', 'UID');
    tblN(d,:) = table({N.Name}, {N.Target}, {N.Type}, {N.Model}, N.Trained, {N.UID});
end

tblN = sortrows(tblN,1); % Sort table by neural net name
end