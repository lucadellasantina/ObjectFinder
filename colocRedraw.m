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