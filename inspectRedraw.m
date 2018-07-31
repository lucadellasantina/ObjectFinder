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
function SelObjID = inspectRedraw(frameNum, ShowObjects, Pos, PosZoom, Post, colmap, NaviRectSize, Dots, Filter)
% Check if Post is RGB or gray, and read frameNum
SelObjID = 0;
if size(Post, 4) == 3 % RGB 3-D matrix (4th dimention is R, G, B)
    f = squeeze(Post(:,:,frameNum,:));
    PostCut = zeros(NaviRectSize(1), NaviRectSize(2),3, 'uint8');
    PostVoxMapCut = PostCut;
    PostCutResized = zeros(size(Post,1), size(Post,2), 3, 'uint8');
    if (Pos(1) > 0) && (Pos(2) > 0) && (Pos(1) < size(Post,2)) && (Pos(2) < size(Post,1))
        % Identify XY borders of the area to zoom according to passed mouse
        % position Pos. Note: Pos(2) is X, Pos(1) is Y
        fxmin = max(ceil(Pos(2) - NaviRectSize(1)/2), 1);
        fxmax = min(ceil(Pos(2) + NaviRectSize(1)/2), size(Post,1));
        fymin = max(ceil(Pos(1) - NaviRectSize(2)/2), 1);
        fymax = min(ceil(Pos(1) + NaviRectSize(2)/2), size(Post,2));
        fxpad = NaviRectSize(1) - (fxmax - fxmin); % add padding if position of selected rectangle fall out of image
        fypad = NaviRectSize(2) - (fymax - fymin); % add padding if position of selected rectangle fall out of image

        % Find only the objects that are within the zoomed area
        passIcut = Filter;
        idx = find(passIcut);
        for i = 1:numel(idx)
            if (Dots.Pos(idx(i),1)>fxmin) && (Dots.Pos(idx(i),1)<fxmax) && (Dots.Pos(idx(i),2)>fymin) && (Dots.Pos(idx(i),2)<fymax)
                %disp('found dot within rect');
                passIcut(idx(i)) = 1;
            else
                passIcut(idx(i)) = 0;
            end
        end
        
        % Flag only voxels of passing objects that are within zoomed area
        VisObjIDs = find(passIcut);
        for i=1:numel(VisObjIDs)
            VoxPos = Dots.Vox(VisObjIDs(i)).Pos;
            for j = 1:size(VoxPos,1)
                if (VoxPos(j,3) == frameNum) && (VoxPos(j,1)>fxmin) && (VoxPos(j,1)<fxmax) && (VoxPos(j,2)>fymin) && (VoxPos(j,2)<fymax)
                    %disp('found voxel in this plane and within selection area');
                    PostVoxMapCut(VoxPos(j,1)+fxpad-fxmin+1,VoxPos(j,2)+fypad-fymin+1,1) = 175;
                end
            end
        end

        % If user clicked an object within the zoomed region, select it
        if (PosZoom(1) > 0) && (PosZoom(2) > 0)
            for i=1:numel(VisObjIDs)
                VoxPos = Dots.Vox(VisObjIDs(i)).Pos;
                for j = 1:size(VoxPos,1)
                    if (VoxPos(j,3) == frameNum) && ( VoxPos(j,1)==(fxpad+fxmin+PosZoom(2)) ) && (VoxPos(j,2)==(fypad+fymin+PosZoom(1)) )
                        %disp('clicked voxel belongs to a validated object');
                        SelObjID = VisObjIDs(i); % Return ID of selected object
                        for k = 1:size(VoxPos,1)
                            if (VoxPos(k,3) == frameNum)
                                PostVoxMapCut(VoxPos(k,1)+fxpad-fxmin+1, VoxPos(k,2)+fypad-fymin+1, 3) = 175;
                                PostVoxMapCut(VoxPos(k,1)+fxpad-fxmin+1, VoxPos(k,2)+fypad-fymin+1, 1) = 0;
                            end
                        end
                    end
                end
            end
            
            if SelObjID == 0
                % Clicked voxel does not belong to any validated object,
                % check if belong to any of the rejected objects intead

                % Find only the rejected objects within the zoomed region
                passIcut = ~Filter; % process only rejected objects
                idx = find(passIcut);
                for i = 1:numel(idx)
                    if (Dots.Pos(idx(i),1)>fxmin) && (Dots.Pos(idx(i),1)<fxmax) && (Dots.Pos(idx(i),2)>fymin) && (Dots.Pos(idx(i),2)<fymax)
                        %disp('found dot within rect');
                        passIcut(idx(i)) = 1;
                    else
                        passIcut(idx(i)) = 0;
                    end
                end
                
                VisObjIDs = find(passIcut); % process only rejected object within zoomed region
                for i=1:numel(VisObjIDs)
                    VoxPos = Dots.Vox(VisObjIDs(i)).Pos;
                    for j = 1:size(VoxPos,1)
                        if (VoxPos(j,3) == frameNum)  && ( VoxPos(j,1)==(fxpad+fxmin+PosZoom(2)) ) && (VoxPos(j,2)==(fxpad+fymin+PosZoom(1)) )
                            SelObjID = VisObjIDs(i); % Return ID of selected object                            
                            for k = 1:size(VoxPos,1)
                                if (VoxPos(k,3) == frameNum)
                                    PostVoxMapCut(VoxPos(k,1)+fxpad-fxmin+1, VoxPos(k,2)+fypad-fymin+1, 3) = 175;
                                    PostVoxMapCut(VoxPos(k,1)+fxpad-fxmin+1, VoxPos(k,2)+fypad-fymin+1, 2) = 0;
                                end
                            end
                        end
                    end                    
                end                
            end

        end        
        
        PostCut(fxpad+1:fxpad+fxmax-fxmin+1, fypad+1:fypad+fymax-fymin+1,1) = f(fxmin:fxmax, fymin:fymax, 1);
        
        % Draw the right panel containing a zoomed version of selected area 
        if ShowObjects
            PostCutResized(:,:,1) = imresize(PostVoxMapCut(:,:,1),[size(Post,1), size(Post,2)], 'nearest');
            PostCutResized(:,:,2) = imresize(PostCut(:,:,1),[size(Post,1), size(Post,2)], 'nearest');
            PostCutResized(:,:,3) = PostCutResized(:,:,1) + imresize(PostVoxMapCut(:,:,3),[size(Post,1), size(Post,2)], 'nearest');
        else
            PostCutResized(:,:,2) = imresize(PostCut(:,:,1),[size(Post,1), size(Post,2)], 'nearest');
            PostCutResized(:,:,1) = PostCutResized(:,:,1).*0;
            PostCutResized(:,:,3) = PostCutResized(:,:,1);
        end
        
        % Separate left and right panel visually with a vertical line
        PostCutResized(1:end    , 1:4      , 1:3) = 75;
        
        % Draw a rectangle over the selected area (left panel)
        f(fxmin:fxmax  , fymin:fymax  , 2)   = f(fxmin:fxmax, fymin:fymax, 2)+50; % green filling
        f(fxmin:fxmax  , fymin:fymin+4, 1:3) = 75; % grey border
        f(fxmin:fxmax  , fymax-4:fymax, 1:3) = 75; % grey border
        f(fxmin:fxmin+4, fymin:fymax  , 1:3) = 75; % grey border
        f(fxmax-4:fxmax, fymin:fymax  , 1:3) = 75; % grey border
        
    end
    
    f = cat(2, f, PostCutResized); % Add the zoomed region to the right of main image
else
    f = Post(:,:,frameNum);
    f(Pos(1),Pos(2)) = 255;
end

% Display
image(f); axis image off
if exist('colmap', 'var')
    colormap(colmap);
end