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
function D = calcDotDensityAlongY(Settings, Objs, Mask, BinsNum, showPlot)
%% Accumulate passing dots coordinates (xyz) into dPosPassF
D.yStart = 1;                    % Analyze the entire volume
D.yEnd = Settings.ImInfo.yNumVox; % Analyze the entire volume
D.binSize = (D.yEnd - D.yStart)/BinsNum; % binning densities every 1 percent of Z-depth
D.binNum = BinsNum;
VoxelVolume = Objs.Settings.ImInfo.xyum * Objs.Settings.ImInfo.xyum * Objs.Settings.ImInfo.zum;

if D.yEnd == D.yStart
    % 2D image (single Z plane)
    D.density = size(Objs.Pos, 1);
    D.densityPerc = zeros(1, BinsNum);
    for i = 1:BinsNum
        D.densityPerc(i) = Density;
    end
    
else
    % 3D image (multiple Z planes) 
    D.density = zeros(1, (D.yEnd - D.yStart +1));
    D.densityPerc = zeros(1, BinsNum);
    D.densityPercMask = zeros(1, BinsNum);
    D.volume = zeros(1, (D.yEnd - D.yStart +1));    
    D.volumePerc = zeros(1, BinsNum);
    D.volumePercMask = zeros(1, BinsNum);
    
    for i = D.yStart: D.yEnd -1
        D.density(i) = numel(find(Objs.Pos(:,1) == i));
        D.volume(i) = mean(Objs.Vol(Objs.Pos(:,1) == i))*VoxelVolume;
    end

    PosPerc = Objs.Pos;
    for i = 1:size(PosPerc,1)    
        PosPerc(i,1) = (PosPerc(i,1)-D.yStart) / (D.yEnd-D.yStart);
        PosPerc(i,1) = ceil(PosPerc(i,1)*BinsNum);
    end
    
    for i = 1:BinsNum
        D.densityPerc(i) = numel(find(PosPerc(:,1) == i));
        D.volumePerc(i) = mean(Objs.Vol(PosPerc(:,1) == i))*VoxelVolume;
    end
    
    if isempty(Mask) || isempty(find(Mask.I(:), 1))
        return
    end
    
    PosPerc = Objs.Pos;
    for i = 1:size(PosPerc,1)
        % Skip if current object is outside of the mask
        if Mask.I(sub2ind(size(Mask.I), PosPerc(i,1), PosPerc(i,2), PosPerc(i,3))) == 0
            PosPerc(i,1) = -1;
            continue
        end
        
        % Calculate Z position of each object as % within the masked volume
        yMask   = squeeze(Mask.I(:, PosPerc(i,2), PosPerc(i,3)));
        yStart  = find(yMask, 1);
        yEnd    = find(yMask, 1, 'last');
        PosPerc(i,1) = (PosPerc(i,1)-yStart) / (yEnd-yStart);
        PosPerc(i,1) = ceil(PosPerc(i,1)*BinsNum);
    end
    
    % Cound how many dots in each % bin
    for i = 1:BinsNum
        D.densityPercMask(i) = numel(find(PosPerc(:,1) == i));
        D.volumePercMask(i) = mean(Objs.Vol(PosPerc(:,1) == i))*VoxelVolume;
    end
end

%% Plot dot density distribution as a function of Volume depth.
if showPlot
    tmpH = figure('Name', 'Grouped distribution along Z');
    set(tmpH, 'Position', [100 200 1200 500]);
    set(gcf, 'DefaultAxesFontName', 'Arial', 'DefaultAxesFontSize', 12);
    set(gcf, 'DefaultTextFontName', 'Arial', 'DefaultTextFontSize', 12);
    
    tiledlayout(1,2);
    nexttile;
    hold on;
    tmpY = D.densityPerc;
    tmpX = (1:BinsNum)*100/BinsNum;
    plot(tmpX, tmpY, 'k', 'MarkerSize', 8);
    plot(tmpX, D.densityPercMask, 'r', 'MarkerSize', 8);    
    box off;
    set(gca, 'color', 'none',  'TickDir','out');
    ylabel('Number of objects');
    xlabel(['Depth percentage (' num2str(100/BinsNum) '% bin size: ' num2str(Settings.ImInfo.xyum * D.binSize, 2) 'um)']);                
    
    nexttile;
    hold on;
    sizeBin = Settings.ImInfo.xyum * Settings.ImInfo.xNumVox...
              *Settings.ImInfo.xyum * D.binSize...
              *Settings.ImInfo.zum * Settings.ImInfo.zNumVox;
    tmpY = D.densityPerc / sizeBin;
    tmpX = (1:BinsNum)*100/BinsNum;
    plot(tmpX, tmpY, 'k', 'MarkerSize', 8);

    if ~isempty(Mask)
        MaskedVoxN = numel(find(Mask.I));
        MaskBinVolume = Settings.ImInfo.xyum *Settings.ImInfo.xyum *Settings.ImInfo.zum * MaskedVoxN / BinsNum;    
        plot(tmpX, D.densityPercMask / MaskBinVolume, 'r', 'MarkerSize', 8);    
    end
    
    box off;
    set(gca, 'color', 'none',  'TickDir','out');
    ylabel('Density (objects / um^3)');
    legend({'Full volume', 'Masked volume'});
    xlabel(['Depth percentage (' num2str(100/BinsNum) '% bin size: ' num2str(Settings.ImInfo.xyum * D.binSize, 2) 'um)']); 
    
    clear tmp* plot_variance sizeBin;
end
end
