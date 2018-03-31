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

function ColocManual = colocManual(Settings, Dots, Filter, Colo, Post, FileName)
%%
Grouped = getFilteredObjects(Dots, Filter);
[~, fName, ~] = fileparts(FileName);
if exist([Settings.TPN 'ColocManual.mat'],'file')
    load([Settings.TPN 'ColocManual.mat']); % Load a previously unfinished analysis
else
    tmpPrompt = {'Reference objects: ', 'Colocalized signal:'};
    tmpAns = inputdlg(tmpPrompt, 'Assign channels', 1, {'PSD95', fName});
    ColocManual.Source = tmpAns{1};
    ColocManual.Fish1 = tmpAns{2};
    
    ManualColocAnalyzingFlag = ones([1,numel(Grouped.Vox)], 'uint8');
    ColocManual.ListDotIDsManuallyColocAnalyzed = find(ManualColocAnalyzingFlag == 1);
    ColocManual.TotalNumDotsManuallyColocAnalyzed = length(ColocManual.ListDotIDsManuallyColocAnalyzed);
    ColocManual.ColocFlag = zeros([1,ColocManual.TotalNumDotsManuallyColocAnalyzed], 'uint8');
end

colocVideoFig(@(frm, ImStk) colocRedraw(frm, ImStk, 'gray(256)'), 5, [], [], ColocManual, Grouped, Post, Colo, Settings);
end




