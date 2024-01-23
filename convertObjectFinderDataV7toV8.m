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

function convertObjectFinderDataV7toV8
%% Convert objectfinder 7.x data format to 8.x data format

    % Create a skeleton folder and move in there any existing skeleton
    if ~exist('skeletons','dir')
        mkdir('objects'); 
    end
    
    if exist('Skel.mat', 'file')
        Skel = load('Skel.mat', 'Skel');
        saveSkel(Skel.Skel);
        delete('Skel.mat'); % Skeleton is now stored inside ./skeletons/
        delete('SkelFiner.mat'); % Skeleton is now stored inside ./skeletons/
    end
    
    
    % Remove 'data' and 'images' folders as no more needed
    if exist([pwd filesep 'data'],'dir')
        rmdir([pwd filesep 'data'], 's'); 
    end
    if exist([pwd filesep 'images'],'dir')
        rmdir([pwd filesep 'images'], 's'); 
    end
    
end