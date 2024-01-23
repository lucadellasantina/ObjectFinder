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

function convertObjectFinderDataV8toV10
%% Convert objectfinder 8.x data format to 10.x data format
disp('Converting Project from Objectfinder 8.x to 10.x format');

% Add version of ObjectFinder used to generate project to Settings
Settings = load('Settings.mat');
Settings.Version = '10.0';
save('Settings.mat', '-struct', 'Settings');

% Convert colocalization info to new format
[Objs, UIDs] = listObjects;

for i= 1:numel(UIDs)
    disp(['  |- Converting ' Objs{i}]);
    Obj = loadObjects(UIDs{i});    
    if isempty(fieldnames(Obj.Coloc))
        continue
    end
    
    ColocList = struct;
    for c = 1:numel(Obj.Coloc)
        ColocOld = Obj.Coloc(c);
        
        ColocNew = struct;
        ColocNew.Ref = ColocOld.Source;
        ColocNew.Dst = ColocOld.Fish1;
        ColocNew.Flag = ColocOld.ColocFlag;

        ColocNew.Settings.Method = ColocOld.Method;
        ColocNew.Settings.NumVoxOverlap = ColocOld.NumVoxOverlap;
        ColocNew.Settings.NumPercOverlap = ColocOld.NumPercOverlap;
        ColocNew.Settings.DistanceWithin = inf;
        ColocNew.Settings.CentroidOverlap = false;
        ColocNew.Settings.RotationAngle = 0;

        ColocNew.Results.ColocNum = ColocOld.NumDotsColoc;
        ColocNew.Results.NonColocNum = ColocOld.NumDotsNonColoc;
        ColocNew.Results.FalseNum = ColocOld.NumFalseDots;
        ColocNew.Results.ColocRate = ColocOld.ColocRate;
        ColocNew.Results.FalseRate = ColocOld.FalseDotRate;   
        
        if isempty(fieldnames(ColocList))
            ColocList = ColocNew;
        else
            ColocList(end+1) = ColocNew; %#ok
        end
    end
    
    Obj.Coloc = ColocList;
    saveObjects(Obj);
end

disp('  |- DONE');
end