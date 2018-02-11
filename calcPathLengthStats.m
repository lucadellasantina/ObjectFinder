%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016,2017,2018 Luca Della Santina
%
%  This program is free software: you can redistribute it and/or modify
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
function calcPathLengthStats(Settings, Grouped, Skel, showPlot)

DotPathLengthList = Skel.FilStats.SkelPathLength2Soma(Grouped.ClosestSkelIDs);
EdgePathLengthList = Skel.FilStats.EdgePathLength2Soma;
EdgeLengthList = Skel.SegStats.Lengths;

EdgePathLengthMax = ceil(max(EdgePathLengthList));

DistBin = 10; %Bin distance is 10 micron by default
DistFromSoma = 5:1:EdgePathLengthMax;
clear NumDots EdgeLengths;
NumDots = zeros(1, length(DistFromSoma));
EdgeLengths = zeros(1, length(DistFromSoma));
for i=1:length(DistFromSoma)
    NumDots(i) = length(find((DotPathLengthList>DistFromSoma(i)-DistBin/2) & (DotPathLengthList<=DistFromSoma(i)+DistBin/2)));
    EdgeLengths(i) = sum(EdgeLengthList((EdgePathLengthList>DistFromSoma(i)-DistBin/2) & (EdgePathLengthList<=DistFromSoma(i)+DistBin/2)));
end
PoverD = NumDots./EdgeLengths;

PathLengthStats.PathLengthBin = DistBin;
PathLengthStats.PathLength2CB = DistFromSoma;
PathLengthStats.PvsPathLength = NumDots;
PathLengthStats.DvsPathLength = EdgeLengths;
PathLengthStats.PoverDvsPathLength = PoverD;
save([Settings.TPN 'PathLengthStats.mat'], 'PathLengthStats');

if showPlot
    width = 20;
    height = 20;
    set(0,'units','centimeters');
    scrsz=get(0,'screensize');
    position=[scrsz(3)/2-width/2 scrsz(4)/2-height/2 width height];
    h=figure;
    set(h,'units','centimeters');
    set(h,'position',position);
    set(h,'paperpositionmode','auto');
    set(0,'units','pixel');
    set(h,'units','pixel');
    set(gcf, 'Color', [0 0 0]);
    
    subplot(3,1,1, 'Color', [0 0 0]), hold on;
    plot(DistFromSoma, NumDots, 'w', 'LineWidth', 2);
    axis([0 EdgePathLengthMax 0 250]);
    set(gca, 'XColor', [1 1 1]); set(gca, 'YColor', [1 1 1]);
    title('bin=10um');
    xlabel('Path length from cell body (µm)');
    ylabel('Total number of dots in the bin');
    
    subplot(3,1,2, 'Color', [0 0 0]), hold on;
    plot(DistFromSoma, EdgeLengths, 'w', 'LineWidth', 2);
    axis([0 EdgePathLengthMax 0 400]);
    set(gca, 'XColor', [1 1 1]); set(gca, 'YColor', [1 1 1]);
    title('bin=10um');
    xlabel('Path length from cell body (µm)');
    ylabel('Total lengths of dendrites in the bin');
    
    subplot(3,1,3, 'Color', [0 0 0]), hold on;
    plot(DistFromSoma, PoverD, 'w', 'LineWidth', 2);
    axis([0 EdgePathLengthMax 0 max(1, max(PoverD))]);
    set(gca, 'XColor', [1 1 1]); set(gca, 'YColor', [1 1 1]);
    title('bin=10um');
    xlabel('Path length from cell body (µm)');
    ylabel('#puncta/µm dendrite');
    
    set(gcf,'inverthardcopy','off'); %this will prevent color change back to default upon saving or printing
    saveas(gcf, [Settings.TPN 'images' filesep 'DotDend_vs_PathLengthStats'], 'tif');
end    
end