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
function D = calcDotDensityAlongZ(Settings, Objs, Mask, showPlot)
%% Accumulate passing dots coordinates (xyz) into dPosPassF
D.zStart = 1;                    % Analyze the entire volume
D.zEnd = Settings.ImInfo.zNumVox; % Analyze the entire volume
D.binSize = (D.zEnd - D.zStart)/100; % binning densities every 1 percent of Z-depth

if D.zEnd == D.zStart
    % 2D image (single Z plane)
    D.density = size(Objs.Pos, 1);
    D.densityPerc = zeros(1, 100);
    for i = 1:100
        D.densityPerc(i) = Density;
    end
    
else
    % 3D image (multiple Z planes) 
    D.density = zeros(1, (D.zEnd - D.zStart +1));
    D.densityPerc = zeros(1, 100);
    D.densityPercMask = zeros(1, 100);

    for i = D.zStart: D.zEnd -1
        D.density(i) = numel(find(Objs.Pos(:,3) == i));
    end
    
    for i = 1:100
        D.densityPerc(i) = D.density(ceil(i*D.binSize));
    end
    
    % Calculate Z position as % within the masked volume
    if ~isempty(Mask) && ~isempty(find(Mask.I(:), 1))
        PosPerc = Objs.Pos;
        for i = size(PosPerc,1)
            zMask   = squeeze(Mask.I(PosPerc(i,1), PosPerc(i,2),:));
            zStart  = find(zMask, 1 );
            zEnd    = find(zMask, 1, 'last' );
            PosPerc(i,3) = ceil(100*(PosPerc(i,3)-zStart) / (zEnd-zStart));
        end
        
        for i = 1:100
            D.densityPercMask(i) = numel(find(PosPerc(:,3) == i));
        end            
    end
end

%% Plot dot density distribution as a function of Volume depth.
if showPlot
    tmpH = figure('Name', 'Grouped distribution along Z');
    set(tmpH, 'Position', [100 200 1200 500]);
    set(gcf, 'DefaultAxesFontName', 'Arial', 'DefaultAxesFontSize', 12);
    set(gcf, 'DefaultTextFontName', 'Arial', 'DefaultTextFontSize', 12);
    
    tiledlayout(1,3);
    nexttile;
    hold on;
    tmpY = D.densityPerc;
    tmpX = 1:100;
    plot(tmpX, tmpY, 'k', 'MarkerSize', 8);
    
    box off;
    set(gca, 'color', 'none',  'TickDir','out');
    ylabel('Number of objects');
    xlabel(['Volume depth % (bin: ' num2str(Settings.ImInfo.zum * D.binSize, 2) 'um)']);
    
    nexttile;
    hold on;
    sizeBin = Settings.ImInfo.xyum * Settings.ImInfo.xNumVox...
              *Settings.ImInfo.xyum * Settings.ImInfo.yNumVox...
              *Settings.ImInfo.zum * D.binSize;
    tmpY = D.densityPerc / sizeBin;
    tmpX = 1:100;
    plot(tmpX, tmpY, 'k', 'MarkerSize', 8);
    
    box off;
    set(gca, 'color', 'none',  'TickDir','out');
    ylabel('Density (objects / um^3)');
    xlabel(['Volume depth % (bin: ' num2str(Settings.ImInfo.zum * D.binSize, 2) 'um)']);
    
    nexttile;
    plot(1:100, D.densityPercMask, 'k', 'MarkerSize', 8);    
    box off;
    set(gca, 'color', 'none',  'TickDir','out');
    ylabel('Density (objects / um^3)');
    xlabel('Mask depth % (bin: 1%)');

    clear tmp* plot_variance sizeBin;
end
end
