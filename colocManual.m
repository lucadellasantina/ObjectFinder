%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2020 Luca Della Santina
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
% *Colocalization - Manual analysis*
% *This scripts allows to analyze whether each object found by ObjectFinder
% is co-localized to another signal of interest (loaded as image stack)
% The user is asked to review each object and judge whether is co-localized
% or non-colocalized to the signal of interest*
%
% Originally written for the colocalization of postsynaptic PSD95 puncta
% and presynaptic CtBP2 puncta.
%
% depends on: colocDotStackCutter.m  colocVideoFig.m
% -------------------------------------------------------------------------

function Coloc = colocManual(Dots, Post, Colo, FileName, Colo2, FileName2)
%%
[~, fName, ~] = fileparts(FileName);
if exist([pwd filesep 'ColocManual.mat'],'file')
    load([pwd filesep 'ColocManual.mat'], 'ColocManual'); % Load a previously unfinished analysis
    if exist([pwd filesep 'ColocManual2.mat'],'file')
        load([pwd filesep 'ColocManual2.mat'], 'ColocManual2'); % Load a previously unfinished analysis
    else
        ColocManual2 = struct;
    end
else
    if isempty(Colo2)
        ColocManual.Ref  = Dots.Name;
        ColocManual.Dst  = fName;
        ColocManual.Flag = zeros([1,numel(Dots.Filter.passF)], 'uint8');
        ColocManual.Flag(find(Dots.Filter.passF == 0)) = 3; % Mark invalid dots as 3 = non-dot
        
        ColocManual.Settings.Method = 'Manual';
        ColocManual.Settings.NumVoxOverlap = 0;
        ColocManual.Settings.NumPercOverlap = 0;
        ColocManual.Settings.DistanceWithin = inf;
        ColocManual.Settings.CentroidOverlap = false;
        ColocManual.Settings.RotationAngle = 0;
        
        ColocManual2 = struct;
    else
        [~, fName2, ~] = fileparts(FileName2);

        ColocManual.Ref  = Dots.Name;
        ColocManual.Dst  = fName;
        ColocManual.Flag = zeros([1,numel(Dots.Filter.passF)], 'uint8');
        ColocManual.Flag(find(Dots.Filter.passF == 0)) = 3; % Mark invalid objects as 3 = false object

        ColocManual.Settings.Method = 'Manual';
        ColocManual.Settings.NumVoxOverlap = 0;
        ColocManual.Settings.NumPercOverlap = 0;
        ColocManual.Settings.DistanceWithin = inf;
        ColocManual.Settings.CentroidOverlap = false;
        ColocManual.Settings.RotationAngle = 0;
        
        ColocManual2 = ColocManual;
        ColocManual2.Dst = fName2;
    end    
end

Coloc = colocVideoFig(ColocManual, Dots, Post, Colo, Colo2, ColocManual2);
end




