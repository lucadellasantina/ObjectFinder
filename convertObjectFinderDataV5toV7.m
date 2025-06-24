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

function convertObjectFinderDataV5toV7
%% Convert objectfinder 5.x or 6.x data format to 7.x data format

    if ~exist('objects','dir')
        mkdir('objects');
    end
    
    load('Dots.mat', 'Dots');
    
    % Ensure Dots structure has a field for shape
    if ~isfield(Dots, 'Shape')
        Dots.Shape = struct;
        Dots.Settings.objfinder.sphericity  = false;
    end
    
    % Ensure Colocalization has fields for Method, NumVoxOverlap, NumPercOverlap
    for idx_dot = 1:numel(Dots)
        if isfield(Dots(idx_dot), 'Coloc') && ~isempty(fieldnames(Dots(idx_dot).Coloc))
            for idx_coloc = 1:numel(Dots(idx_dot).Coloc)
                if ~isfield(Dots(idx_dot).Coloc(idx_coloc), 'Method') || isempty(Dots(idx_dot).Coloc(idx_coloc).Method)
                    Dots(idx_dot).Coloc(idx_coloc).Method = 'Unknown';
                    Dots(idx_dot).Coloc(idx_coloc).NumVoxOverlap  = 0;
                    Dots(idx_dot).Coloc(idx_coloc).NumPercOverlap  = 0;
                end
            end
        end
    end

    for i = 1:numel(Dots)                
        saveObjects(Dots(i));
    end
    
    delete('Dots.mat'); % Dots are now stored inside /objects/ folder
    delete('Colo.mat'); % No more need to store colo image, done in memory
end