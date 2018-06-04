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
% *ObjectFinder allows to analyze an image volume containing objects
% (i.e. labeling of synaptic structures) with the final goal of segmenting
% each individual object and computing its indivudual properties.*
%
% *This program calculates the Nearest Neighbor distance for a list of cells. 
%
% Each row of the reference points' matrix is the [X,Y,Z] coordinates of 
% each cell. 
%
% The program performs the following main operations:
%
% # Ask user to choose the cell list 
% # Calculate NN distance
% # Plot NN distance distributio
%
% *Input:*
%
% * Reference points: one matrix containing coordinates of cells
%  
% *Output:*
%
% Plot NN distances as frequency histograms
% Plot Cumulative distribution of NN distances

%% Find nearest neighbor distance for each point in a group
% Each point is an entry in a n x 3 array containing xyz coordinates

[tmpName] = listdlg('PromptString','Select points',...
                           'SelectionMode','single', 'ListString',who);
tmpVars=who; %list available variables
tmpPts=evalin('base',char(tmpVars(tmpName))); %retrieve selected experiment data
clear tmpName tmpVars;

% TODO: make user define these parameters
%xyum = 0.103;  % Olympus PLAPO 60x zoom1
%zum = 0.3;     % Olympus PLAPO 60x zoom1
xyum = 0.31;   % Olympus PLAPO 20x zoom1
zum = 1;       % Olympus PLAPO 20x zoom1
dist3D = false; % Calculate 3d distance?

tmpPtsN = size(tmpPts,1);
for j = tmpPtsN:-1:1
        if j == tmpPtsN % dont want to find self
            searchBox = (1:tmpPtsN-1);
        elseif j>1 && j<tmpPtsN
            searchBox = ([1:(j-1) (j+1):tmpPtsN]);
        else 
            searchBox = (2:tmpPtsN);
        end
        k = searchBox;
            xyDistUm = hypot(tmpPts(j,1).*xyum-tmpPts(k,1).*xyum, tmpPts(j,2).*xyum-tmpPts(k,2).*xyum); %vYesSpotsXYZ from imaris is transposed over the xy axis so Dots and vYes.. have switched XY
            xyzDistUm= hypot(xyDistUm, (tmpPts(j,3).*zum-tmpPts(k,3).*zum));
        
        if dist3D
            NNDist(j)= min(xyzDistUm);
        else
            NNDist(j)= min(xyDistUm);
        end
end

clear xyum zum tmp* searchbox j k ans searchbox searchBox xyDistUm xyzDistUm dist3D;
%% Randomly generate the same amount of points as the given dataset
% generated points must be spaced at least tmpMinDist microns

[tmpName] = listdlg('PromptString','Select points',...
                           'SelectionMode','single', 'ListString',who);
tmpVars=who; %list available variables
tmpPts=evalin('base',char(tmpVars(tmpName))); %retrieve selected experiment data
clear tmpName tmpVars;

tmpPtsN = size(tmpPts,1);
tmpMax = max(tmpPts);
tmpMin = min(tmpPts);

% TODO: make user define these parameters
%xyum = 0.103;  % Olympus PLAPO 60x zoom1
%zum = 0.3;     % Olympus PLAPO 60x zoom1
xyum = 0.31;   % Olympus PLAPO 20x zoom1
zum = 1;       % Olympus PLAPO 20x zoom1
tmpMinDist = 1 / xyum;
dist3D = false; % Calculate 3d distance?

tmpPtsN = size(tmpPts,1);
tmpRndPts = [];
while size(tmpRndPts, 1) < tmpPtsN
    % Generate new random point coordinates
    tmpRndPt = [randi([tmpMin(1) tmpMax(1)],1,1),...
                randi([tmpMin(2) tmpMax(2)],1,1),...
                randi([tmpMin(3) tmpMax(3)],1,1)];
            
    if isempty(tmpRndPts)
        tmpRndPts = cat(1, tmpRndPts, tmpRndPt);
    else
        % Check that the new point is not closer than tmpMinDist to any of
        % previously generated points.
        xyDist = hypot(tmpRndPt(1)-tmpRndPts(:,1), tmpRndPt(2)-tmpRndPts(:,2));
        xyzDist= hypot(xyDist, (tmpRndPt(3)-tmpRndPts(:,3)));
        if dist3D
            if min(xyzDist) > tmpMinDist, tmpRndPts = cat(1, tmpRndPts, tmpRndPt);end
        else
            if min(xyDist) > tmpMinDist, tmpRndPts = cat(1, tmpRndPts, tmpRndPt);end
        end
    end
end
randomPts = tmpRndPts;
clear tmp* xyum zum xyDist xyzDist dist3D;

%% Plot distribution properties of nearest neighbor distances
%
[tmpName] = listdlg('PromptString','Empirical NN distances',...
                           'SelectionMode','single', 'ListString',who);
tmpVars=who; %list available variables
tmpEmpNNDist=evalin('base',char(tmpVars(tmpName))); %retrieve selected experiment data
clear tmpName tmpVars;

[tmpName] = listdlg('PromptString','Random NN distances',...
                           'SelectionMode','single', 'ListString',who);
tmpVars=who; %list available variables
tmpRndNNDist=evalin('base',char(tmpVars(tmpName))); %retrieve selected experiment data
clear tmpName tmpVars;


%Relative frequency plot
subplot(2,1,1);
hold on;
[n, xout] = hist(tmpRndNNDist, numel(tmpEmpNNDist)/5);% Random data
%[tmpMu, tmpSigma] = normfit(xout); % Fit with normal distribution
bar(xout, n/sum(n)*100, 'FaceColor', [.8 .8 .8], 'EdgeColor', [.3 .3 .3]);
[n, xout] = hist(tmpEmpNNDist, numel(tmpEmpNNDist)/5); % Empirical data
tmpH = bar(xout, n/sum(n)*100, 'FaceColor', 'r', 'EdgeColor', 'r');
tmpH = get(tmpH, 'child');
set(tmpH, 'facea', 0.3);
title('Relative frequency');
ylabel('Relative frequency (%)');
legend('Random', 'Empirical', 'Location', 'NorthEast');
xlim([0 25]);

% Cumulative distribution plot
subplot(2,1,2) 
hold on;
[tmpH, tmpStats] = cdfplot(tmpRndNNDist); % Random data
tmpYdata = get(tmpH, 'YData');
set(tmpH, 'YData', tmpYdata*100);
set(tmpH, 'color', [.3 .3 .3]);

[tmpH, tmpStats] = cdfplot(tmpEmpNNDist); % Empirical data
tmpYdata = get(tmpH, 'YData');
set(tmpH, 'YData', tmpYdata*100);
set(tmpH, 'color', 'r');

title('Cumulative distribution');
xlabel('Nearest neighbor distance');
ylabel('Fraction of total (%)');
legend('Random', 'Empirical', 'Location', 'SouthEast');
xlim([0 25]);

set(gcf, 'MenuBar', 'None');
clear tmp* n xout;

%% Plot selected points collapsed on a single xy plane

[tmpName] = listdlg('PromptString','Select points',...
                           'SelectionMode','single', 'ListString',who);
tmpVars=who; %list available variables
tmpPts=evalin('base',char(tmpVars(tmpName))); %retrieve selected experiment data
clear tmpName tmpVars;

% TODO: make user define these parameters
xySizePx = 2048;
%xyum = 0.103;  % Olympus PLAPO 60x zoom1
xyum = 0.31;   % Olympus PLAPO 20x zoom1
dotSizePx = 7 / xyum;

figure;
tmpH = scatter(tmpPts(:,1), tmpPts(:,2), dotSizePx);
xlim([1 xySizePx]);
ylim([1 xySizePx]);

axis off;
set(gcf, 'MenuBar', 'None');
clear tmp* n xout;

clear xySizePx dotSizePx xyum tmp*;

%% Changelog
%
% _*Version 1.0*             created on 2017-10-03 by Luca Della Santina_
%
%  + Calculates the NN distance of a set of empirical points
%  + Calculates the NN distance of a randomly distributed set of points
%  + Plot NN distance and cumulative distribution of NN distances
%  + Calculations can be done either in 2D or 3D
%  + Plots the position of points in 2D for visualization