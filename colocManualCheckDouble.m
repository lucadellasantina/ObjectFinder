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

function Coloc = colocManualCheckDouble(Dots, Filter, Post, Colo, ColocManual, Colo2, ColocManual2)
if isempty(Colo2) % Single channel, check only colocalized objects
    % Find objects that are colocalized with both channels
    Coloc1 = find(ColocManual.ColocFlag==1); % Numbers of colocalized dots analyzed
    
    % Flag as 0 (redo) those objects in order to re-analyze them
    ColocManual.ColocFlag(Coloc1) = 0;
    ColocManual.NumDotsColoc = ColocManual.NumDotsColoc - numel(Coloc1);
    
    % Re-annalyze only double colocalized objects
    Grouped = getFilteredObjects(Dots, Filter);
    Coloc = colocVideoFig(@(frm, ImStk) colocRedraw(frm, ImStk, 'gray(256)'), ColocManual, Grouped, Post, Colo, Colo2, ColocManual2);
else % 2 Colocalizing channels, check only double-colocalized objects
    % Find objects that are colocalized with both channels
    Coloc1 = find(ColocManual.ColocFlag==1); % Numbers of colocalized dots analyzed
    Coloc2 = find(ColocManual2.ColocFlag==1); % Numbers of colocalized dots analyzed
    Coloc12 = intersect(Coloc1, Coloc2);
    
    % Flag those objects off in order to re-analyze them
    ColocManual.ColocFlag(Coloc12) = 0;
    ColocManual.NumDotsColoc = ColocManual.NumDotsColoc - numel(Coloc12);
    
    ColocManual2.ColocFlag(Coloc12) = 0;
    ColocManual2.NumDotsColoc = ColocManual2.NumDotsColoc - numel(Coloc12);
    
    % Re-annalyze only double colocalized objects
    Grouped = getFilteredObjects(Dots, Filter);
    Coloc = colocVideoFig(@(frm, ImStk) colocRedraw(frm, ImStk, 'gray(256)'), ColocManual, Grouped, Post, Colo, Colo2, ColocManual2);
end
end
