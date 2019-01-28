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

function Coloc = colocManual(Dots, Filter, Post, Colo, FileName, Colo2, FileName2)
%%
Grouped = getFilteredObjects(Dots, Filter);
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
        ColocManual.Source  = Dots.Name;
        ColocManual.Fish1   = fName;
    
        ManualColocAnalyzingFlag = ones([1,numel(Grouped.Vox)], 'uint8');
        ColocManual.ListDotIDsManuallyColocAnalyzed = find(ManualColocAnalyzingFlag == 1);
        ColocManual.TotalNumDotsManuallyColocAnalyzed = length(ColocManual.ListDotIDsManuallyColocAnalyzed);
        ColocManual.ColocFlag = zeros([1,ColocManual.TotalNumDotsManuallyColocAnalyzed], 'uint8');
        ColocManual.Method            = 'Manual';
        ColocManual.NumVoxOverlap     = 0;
        ColocManual.NumPercOverlap    = 0;
        ColocManual2 = struct;
    else
        [~, fName2, ~] = fileparts(FileName2);

        ColocManual.Source  = Dots.Name;
        ColocManual.Fish1   = fName;       

        ManualColocAnalyzingFlag = ones([1,numel(Grouped.Vox)], 'uint8');
        ColocManual.ListDotIDsManuallyColocAnalyzed = find(ManualColocAnalyzingFlag == 1);
        ColocManual.TotalNumDotsManuallyColocAnalyzed = length(ColocManual.ListDotIDsManuallyColocAnalyzed);
        ColocManual.ColocFlag = zeros([1,ColocManual.TotalNumDotsManuallyColocAnalyzed], 'uint8');
        ColocManual.Method            = 'Manual';
        ColocManual.NumVoxOverlap     = 0;
        ColocManual.NumPercOverlap    = 0;
        
        ColocManual2 = ColocManual;
        ColocManual2.Fish1 = fName2;
    end    
end

Coloc = colocVideoFig(@(frm, ImStk) colocRedraw(frm, ImStk, 'gray(256)'), ColocManual, Grouped, Post, Colo, Colo2, ColocManual2);
end




