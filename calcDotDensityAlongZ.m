function [dotDensity] = calcDotDensityAlongZ(Grouped)
%% Accumulate passing dots coordinates (xyz) into dPosPassF
dotDensity.zStart = 1;                    % Analyze the entire volume
dotDensity.zEnd = Grouped.ImInfo.zNumVox; % Analyze the entire volume
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
xlabel(['Volume depth percentage (bin size = ' num2str(Grouped.ImInfo.zum*dotDensity.binSize) ' um)']);

subplot(1,2,2);
hold on;
sizeBin = Grouped.ImInfo.xyum*Grouped.ImInfo.xNumVox...
               *Grouped.ImInfo.xyum*Grouped.ImInfo.yNumVox...
               *Grouped.ImInfo.zum*dotDensity.binSize;
tmpY = dotDensity.densityPerc / sizeBin;
tmpX = 1:100;
plot(tmpX, tmpY, 'k', 'MarkerSize', 8);

box off;
set(gca, 'color', 'none',  'TickDir','out');
ylabel('Density (objects / um^3)');
xlabel('Volume depth percentage');

clear tmp* plot_variance sizeBin;
end
