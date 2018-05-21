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
function inspectVolume2D(Post, Dots, Filter)
% Prepare volume for inspection
CutNumVox = [256, 256, size(Post, 3)]; % Magnify a zoom region of this size
ImStk = cat(4, Post, Post, Post); % Create an RGB version of Post

% Visualize volume as video frames
redraw_func = @(frm, ShowObjects, Pos, Filter) inspectRedraw(frm, ShowObjects, Pos, ImStk, 'gray(256)', CutNumVox, Dots, Filter);
inspectVideoFig(size(ImStk,3), redraw_func, [], [], ImStk, Dots, Filter);
end