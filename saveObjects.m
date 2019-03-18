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


function saveObjects(Dots, FieldName)
%% Save a variable into a .mat file efficiently depending on its size
    
    if nargin == 1
        % If no FieldName then save all field of Dots on file
        FieldName = []; 
    end
    
    if ~isfield(Dots, 'UID')
        Dots.UID = generateUID;
    end
    FileName = [pwd filesep 'objects' filesep Dots.UID '.mat'];
    
    lastwarn('') % Clear last warning message
    
    if isempty(FieldName)
        % Save struct on file with fields split tino separate variables
        save(FileName, '-struct', 'Dots', '-v7');
        [warnMsg, ~] = lastwarn;
        if ~isempty(warnMsg)
            disp('Objects are bigger than 2Gb, will be saved using larger file format, be patient...')
            save(FileName, '-struct', Dots, '-v7.3', '-nocompression');
        end
    else
        % Save only a specific FieldName on disk
        save(FileName, '-struct', 'Dots', FieldName,'-append');
        [warnMsg, ~] = lastwarn;
        if ~isempty(warnMsg)
            disp('Objects are bigger than 2Gb, will be saved using larger file format, be patient...')
            save(FileName, '-struct', 'Dots', FieldName, '-append');
        end
    end    
end