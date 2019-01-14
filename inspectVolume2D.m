%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2019 Luca Della Santina
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
function create_new_objs = inspectVolume2D(Post, Dots, Filter)
% Prepare volume for inspection
CutNumVox = [min(256, size(Post,1)), min(256, size(Post,2)), size(Post,3)]; % Magnify a zoom region of this size
ImStk = cat(4, Post, Post, Post); % Create an RGB version of Post

% Visualize volume as video frames
redraw_func = @(frm, ShowObjects, Pos, PosZoom, CutNumVox, Filter) inspectRedraw(frm, ShowObjects, Pos, PosZoom, ImStk, 'gray(256)', CutNumVox, Dots, Filter);
inspectVideoFig(size(ImStk,3), redraw_func, [], [], ImStk, Dots, Filter, CutNumVox);
end