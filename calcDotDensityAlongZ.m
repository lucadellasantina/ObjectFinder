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
function [dotDensity] = calcDotDensityAlongZ(Settings, Grouped, showPlot)
%% Accumulate passing dots coordinates (xyz) into dPosPassF
dotDensity.zStart = 1;                    % Analyze the entire volume
dotDensity.zEnd = Settings.ImInfo.zNumVox; % Analyze the entire volume
dotDensity.binSize = (dotDensity.zEnd - dotDensity.zStart)/100; % binning densities every 1 percent of Z-depth

tmpDensity=zeros(1, (dotDensity.zEnd - dotDensity.zStart +1));
tmpDensityPerc=zeros(1, 100);
for i = dotDensity.zStart: dotDensity.zEnd -1
    tmpDensity(i) = numel(find(Grouped.Pos(:,3) == i));
    tmpDensityPerc(ceil(i/dotDensity.binSize)) = tmpDensityPerc(ceil(i/dotDensity.binSize)) + tmpDensity(i);
end

dotDensity.density = tmpDensity;
dotDensity.densityPerc = tmpDensityPerc;
clear tmp* i passingIDs PassDotIDs ans Dots SG;

%% Plot dot density distribution as a function of Volume depth.
if showPlot
    tmpH = figure('Name', 'Grouped distribution along Z');
    set(tmpH, 'Position', [100 200 1200 500]);
    set(gcf, 'DefaultAxesFontName', 'Arial', 'DefaultAxesFontSize', 12);
    set(gcf, 'DefaultTextFontName', 'Arial', 'DefaultTextFontSize', 12);
    
    subplot(1,2,1);
    hold on;
    tmpY = dotDensity.densityPerc;
    tmpX = 1:100;
    plot(tmpX, tmpY, 'k', 'MarkerSize', 8);
    
    box off;
    set(gca, 'color', 'none',  'TickDir','out');
    ylabel('Number of objects');
    xlabel(['Volume depth percentage (bin size = ' num2str(Settings.ImInfo.zum*dotDensity.binSize) ' um)']);
    
    subplot(1,2,2);
    hold on;
    sizeBin = Settings.ImInfo.xyum*Settings.ImInfo.xNumVox...
        *Settings.ImInfo.xyum*Settings.ImInfo.yNumVox...
        *Settings.ImInfo.zum*dotDensity.binSize;
    tmpY = dotDensity.densityPerc / sizeBin;
    tmpX = 1:100;
    plot(tmpX, tmpY, 'k', 'MarkerSize', 8);
    
    box off;
    set(gca, 'color', 'none',  'TickDir','out');
    ylabel('Density (objects / um^3)');
    xlabel('Volume depth percentage');
    
    clear tmp* plot_variance sizeBin;
end
end
