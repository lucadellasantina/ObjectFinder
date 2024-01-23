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

function [Image, ImInfo, MIP, ImRes] = loadImage(FileName)
%%
    PathName = [pwd filesep 'I' filesep];
    if ~isempty(FileName)
        fileInfo = dir([PathName FileName]);
        if isempty(fileInfo)
            return
        end
        
        if fileInfo.bytes > 4e+9
            % Image file is bigger than 4Gb using custom imread function
            ImInfo = imfinfo([PathName FileName]);
            Image = uint8(imread_big([PathName FileName]));
        else
            ImInfo = imfinfo([PathName FileName]);
%             Image = zeros(ImInfo(1).Height, ImInfo(1).Width, length(ImInfo));
%             for j = 1:length(ImInfo)
%                 Image(:,:,j)=imread([PathName FileName], j);
%             end
            Image = tiffreadVolume([PathName FileName]);
            Image = uint8(Image);
        end
        
        % Retrieve image calibration from TIF file descriptor
        try
            tmpXYres = num2str(1/ImInfo(1).XResolution);
            if contains(ImInfo(1).ImageDescription, 'spacing=')
                tmpPos = strfind(ImInfo(1).ImageDescription,'spacing=');
                tmpZres = ImInfo(1).ImageDescription(tmpPos+8:end);
                tmpZres = regexp(tmpZres,'\n','split');
                tmpZres = tmpZres{1};
            else
                tmpZres = '1'; % for 2D images which have no spacing field default is 1 in ImageJ
            end
        catch
            tmpXYres = '1'; % default values
            tmpZres  = '1'; % default values
        end        
        ImRes = [str2double(tmpXYres), str2double(tmpXYres), str2double(tmpZres)];
        
        % Compute maximum intensity projection
        MIP = squeeze(max(Image,[],3)); % Create a MIP of each image to display
    end
end

function stack_out = imread_big(stack_name)
    % Get data block size
    ImInfo = imfinfo(stack_name);
    stripOffset = ImInfo(1).StripOffsets;
    stripByteCounts = ImInfo(1).StripByteCounts;

    % Get image size
    sz_x = ImInfo(1).Width;
    sz_y = ImInfo(1).Height;
    if length(ImInfo)<2
        Nframes=floor(ImInfo(1).FileSize/stripByteCounts);
    else
        Nframes=length(ImInfo);
    end

    fID = fopen (stack_name, 'r');

    if ImInfo(1).BitDepth==16
        stack_out = zeros([sz_y sz_x Nframes],'uint16');
    else
        stack_out = zeros([sz_y sz_x Nframes],'uint8');
    end

    start_point = stripOffset(1) + (0:1:(Nframes-1)).*stripByteCounts;

    for i = 1:Nframes
        %fprintf ('loading image ... %d\n', i);
        fseek (fID, start_point(i)+1, 'bof');

        if ImInfo(1).BitDepth==16
            A = fread (fID, [sz_x sz_y], 'uint16=>uint16');
        else
            A = fread (fID, [sz_x sz_y], 'uint8=>uint8');
        end

        stack_out(:,:,i) = A';
    end
end