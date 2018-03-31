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
function colocRedraw(frame, vidObj, colmap)
%   REDRAW (FRAME, VIDOBJ)
%       frame  - frame number to process
%       vidObj - mmread object
%       colmap - colormap of your image, not necessary for RGB image, and
%                even if you specify any colormap for RGB, it will not do
%                anything to your image.

% Check if vidOjb is RGB or gray, and read frame
if size(vidObj, 4) == 3 %RGB 3-D matrix (4th dimention is R, G, B)
    f = squeeze(vidObj(:,:,frame,:));
else
    f = vidObj(:,:,frame);
end

% Display
image(f); axis image off
if exist('colmap', 'var')
    colormap(colmap);
end