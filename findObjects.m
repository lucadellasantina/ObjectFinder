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
% *Find objects using an iterative thresholding approach*
% -------------------------------------------------------------------------
% The object finder searches for individual objects within the volume by
% first dividing the volume in multiple sub-blocks and then applying the
% following steps to each search block:
%
% Step 1: Iteratively scan the volume to create a scoring map
% Step 2: Segment objects with multiple scoring peaks using watershed
% Step 3: Calculate volume, position, scoring and intensity of each object
% Step 4: Resolve objects laying across multiple search blocks 
%
% Tested with object in the approx. shape of ellipsoids (synaptic puncta)
% 
% Version 3.0                               2017-11-07  Luca Della Santina
%
%  + Multi-threaded computation of Step#1 and Step#2 using parfor
%  - Removed dependency from mask (D) and TPN
%  % Removed losing dots if they are left without any more voxel (Step #4)
%
% Version 2.0                               2017-08-03  Luca Della Santina
%
%  + Split computation in 4 fundamental steps
%  + Improved ~15% speed by switching from bwlabeln to conncomp+labelmatrix
%  % Relevant settings are passed to the function as parameters
%
% Version 1.0 formerly DotFinder   2010-xx-xx  Haruhisa Okawa/Adam Bleckert
%                                  2008-xx-xx  Josh Morgan
%
% input: TPN: path to working directory
%        Post: 3D image stack of channel to search for objects
%        Settings: settings for the dofinding process
%
% output: Dots (containing informatio about each recognized object
%         Settings (containing updated settings informations)
%
% dependencies: txtBar.m
%               image processing toolbox
%
% -------------------------------------------------------------------------

function[Dots, Settings]=findObjects(Post, Settings)

% Retrieve parameters to use from Settings
debug = Settings.debug;
blockSize = Settings.dotfinder.blockSize;
blockBuffer = Settings.dotfinder.blockBuffer;
thresholdStep = Settings.dotfinder.thresholdStep;
maxDotSize = Settings.dotfinder.maxDotSize;
minDotSize = Settings.dotfinder.minDotSize;
itMin = Settings.dotfinder.itMin;
minFinalDotITMax = Settings.dotfinder.minFinalDotITMax;
minFinalDotSize = Settings.dotfinder.minFinalDotSize;
MultiPeakDotSizeCorrectionFactor=Settings.dotfinder.MultiPeakDotSizeCorrectionFactor;
peakCutoffUpperBound = Settings.dotfinder.peakCutoffUpperBound;
peakCutoffLowerBound = Settings.dotfinder.peakCutoffLowerBound;

if debug 
    subplot(2,1,1);
    colormap gray(255);
    image(max(Post,[],3));
    pause(.01); 
end

if debug 
    subplot(2,1,2);
    colormap gray(255);
    image(max(Post,[],3));
    pause(1); 
end

% Calculate the block size to Subsample the volume
[Rys, Rxs, Rzs] = size(Post);

if Rxs>blockSize
    NumBx=round(Rxs/blockSize);
    Bxc=fix(Rxs/NumBx);
else
    Bxc=Rxs;
    NumBx=1;
end

if Rys>blockSize
    NumBy=round(Rys/blockSize);
    Byc=fix(Rys/NumBy);
else
    Byc=Rys;
    NumBy=1;
end

if Rzs>blockSize
    NumBz=round(Rzs/blockSize);
    Bzc=fix(Rzs/NumBz);
else
    Bzc=Rzs;
    NumBz=1;
end

%% -- STEP 1: scan the volume and find areas crossing local contrast threshold with a progressively coarser intensity filter --
clear tmpBlocks;
tmpBlocks(NumBx * NumBy * NumBz) = struct;
fprintf('Searching candidate objects using multi-threaded iterarive threshold ... ');
tic;

parfor block = 1:(NumBx*NumBy*NumBz)
    [Bx, By, Bz] = ind2sub([NumBx, NumBy, NumBz], block);
    %disp(['current block = Bx:' num2str(Bx) ', By:' num2str(By) ', Bz:' num2str(Bz)]);
    
    %Find real territory
    Tystart=(By-1)*Byc+1;
    Txstart=(Bx-1)*Bxc+1;
    Tzstart=(Bz-1)*Bzc+1;
    
    if By<Byc, Tyend=By*Byc; else, Tyend=Rys; end
    if Bx<Bxc, Txend=Bx*Bxc; else, Txend=Rxs; end
    if Bz<Bzc, Tzend=Bz*Bzc; else, Tzend=Rzs; end
    
    %Find buffered Borders (if last block, extend to image borders)
    yStart=Tystart-blockBuffer;
    yStart(yStart<1)=1;
    yEnd=Tyend+blockBuffer;
    yEnd(yEnd>Rys)=Rys;
    xStart=Txstart-blockBuffer;
    xStart(xStart<1)=1;
    xEnd=Txend+blockBuffer;
    xEnd(xEnd>Rxs)=Rxs;
    zStart=Tzstart-blockBuffer;
    zStart(zStart<1)=1;
    zEnd=Tzend+blockBuffer;
    zEnd(zEnd>Rzs)=Rzs;
    
    % Slice the raw image into the block of interest (Igm)
    Igm = Post(yStart:yEnd,xStart:xEnd,zStart:zEnd);
    % Search only between max intensity (Gmax) and noise intensity level (Gmode)
    Gmode = mode(Igm(Igm>0)); % Most common intensity found in the block (noise level)
    Gmax = max(Igm(:));       % Maximum intensity found in the block
    [ys,xs,zs] = size(Igm);

    peakMap = zeros(ys,xs,zs,'uint8');      % Initialize matrix to map peaks found
    thresholdMap = zeros(ys,xs,zs,'uint8'); % Initialize matrix to sum passed thresholds
    
    % Make sure Gmax can be divided by the stepping size of thresholdStep
    if mod(Gmax, thresholdStep) ~= mod(Gmode+1, thresholdStep), Gmax = Gmax+1; end
    
    % Scan volume to find areas crossing contrast threshold with progressively coarser intensity filter
    for i = Gmax:-thresholdStep:Gmode+1 % Iterate from Gmax to noise level (Gmode+1) within each block
        % Label all areas in the block (Igl) that crosses the intensity threshold "i"
        
        %[Igl,labels] = bwlabeln(Igm>i,6); %OLD version, slower
        CC = bwconncomp(Igm>i,6); % using bwconncomp+labelmatric instead of bwlabeln increases speed about 10% LDS 2017-08-02
        labels = CC.NumObjects;
        Igl = labelmatrix(CC);
        
        if labels == 0
            continue;
        elseif labels <= 1
            labels = 2;
        end
        if labels<65536
            Igl=uint16(Igl);
        end % Reduce bitdepth if possible
        
        nPixel = hist(Igl(Igl>0), 1:labels);
        
        for p=1:labels
            pixelIndex = find(Igl==p);
            
            % Adjust max dot size if multi-peak object is found HO 2/8/2011
            NumPeaks = sum(peakMap(pixelIndex));
            if NumPeaks == 0
                maxCompoundDotSize = maxDotSize;
            else
                maxCompoundDotSize = maxDotSize + maxDotSize*(NumPeaks-1)*MultiPeakDotSizeCorrectionFactor;
            end
            
            % Identify the peak location in each labeled object whose size is within min and max DotSize
            if (nPixel(p) < maxCompoundDotSize) && (nPixel(p) > minDotSize)
                if sum(peakMap(pixelIndex))== 0 % sets up critireon to limit one peak per labeled field "Igl"
                    peakValue = max(Igm(pixelIndex));
                    peakIndex = find(Igl==p & Igm==peakValue);
                    if numel(peakIndex) > 1
                        peakIndex = peakIndex(round(numel(peakIndex)/2));
                    end
                    [y,x,z] = ind2sub([ys xs zs], peakIndex);
                    peakMap(y,x,z) = 1; % Register the peak position in peak map
                end
            else
                Igl(pixelIndex)=0;
            end
        end
        thresholdMap(Igl>0) = thresholdMap(Igl>0)+1; % Add 1 to the threshold score of all peaks that passed this iteration
        
    end % for all intensities
    
    thresholdMap(thresholdMap<itMin) = 0;                 % only puncta with more than 2 IT pass are analyzed, I set to 2 for now because you want to save voxels of IT = 2 for the dot of ITmax = 4, for example. HO 2/8/2011
    tmpBlocks(block).thresholdMap = thresholdMap;         % Store for later
    tmpBlocks(block).peakMap = peakMap;                   % Store for later
    tmpBlocks(block).sizeIgm = [ys, xs, zs];              % Store for later
    tmpBlocks(block).startPos = [yStart, xStart, zStart]; % Store for later
    tmpBlocks(block).endPos = [yEnd, xEnd, zEnd];         % Store for later
    tmpBlocks(block).nLabels = 0;                    % initialize for later
    tmpBlocks(block).wsTMLabels = [];                % initialize for later
    tmpBlocks(block).wsLabelList = [];               % initialize for later
end

fprintf(['DONE in ' num2str(toc) ' seconds \n']);

%% -- STEP 2: Find the countour of each dot and split it using watershed if multiple peaks are found within the same dot --
fprintf('Separate objects with multiple peaks using multi-threaded watershed segmentation... ');
tic;

parfor block = 1:(NumBx*NumBy*NumBz)
    ys = tmpBlocks(block).sizeIgm(1);              % retrieve values
    xs = tmpBlocks(block).sizeIgm(2);              % retrieve values
    zs = tmpBlocks(block).sizeIgm(3);              % retrieve values
    thresholdMap = tmpBlocks(block).thresholdMap;  % retrieve values
    
    wsThresholdMapBin = uint8(thresholdMap>0);                        % binary map of threshold
    wsThresholdMapBinOpen = imdilate(wsThresholdMapBin, ones(3,3,3)); % dilate Bin map with a 3x3x3 kernel (dilated perimeter acts like ridges between background and ROIs)
    wsThresholdMapComp = imcomplement(thresholdMap);                  % complement (invert) image. Required because watershed() separate holes, not mountains. imcomplement creates complement using the entire range of the class, so for uint8, 0 becomes 255 and 255 becomes 0, but for double 0 becomes 1 and 255 becomes -254.
    wsTMMod = wsThresholdMapComp.*wsThresholdMapBinOpen;              % Force background outside of dilated region to 0, and leaves walls of 255 between puncta and background.
    wsTMLabels = watershed(wsTMMod, 6);                               % 6 voxel connectivity watershed, this will fill background with 1, ridges with 0 and puncta with 2,3,4,... in double format
    wsBackgroundLabel = mode(double(wsTMLabels(:)));                  % calculate background level
    wsTMLabels(wsTMLabels == wsBackgroundLabel) = 0;                  % seems that sometimes Background can get into puncta... so the next line was not good enough to remove all the background labels.
    wsTMLabels = double(wsTMLabels).*double(wsThresholdMapBin);       % masking out non-puncta voxels, this makes background and dilated voxels to 0. This also prevents trough voxels from being added back somehow with background. HO 6/4/2010
    wsTMLZeros = find(wsTMLabels == 0 & thresholdMap > 0);            % find zeros of watersheds inside of thresholdmap (add back the zero ridges in thresholdMap to their most similar neighbors)
    
    if ~isempty(wsTMLZeros) % if exist zeros in the map
        [wsTMLZerosY, wsTMLZerosX, wsTMLZerosZ] = ind2sub(size(thresholdMap),wsTMLZeros); %6/4/2010 HO
        for j = 1:length(wsTMLZeros) % create a dilated matrix to examine neighbor connectivity around the zero position
            tempZMID =  wsTMLabels(max(1,wsTMLZerosY(j)-1):min(ys,wsTMLZerosY(j)+1), max(1,wsTMLZerosX(j)-1):min(xs,wsTMLZerosX(j)+1), max(1,wsTMLZerosZ(j)-1):min(zs,wsTMLZerosZ(j)+1)); %HO 6/4/2010
            nZeroID = mode(tempZMID(tempZMID~=0)); % find most common neighbor value (watershed) not including zero
            wsTMLabels(wsTMLZeros(j)) = nZeroID;   % re-define zero with new watershed ID (this process will act similar to watershed by making new neighboring voxels feed into the decision of subsequent zero voxels)
        end
    end
    wsTMLabels = uint16(wsTMLabels);
    wsLabelList = unique(wsTMLabels);
    wsLabelList(1) = []; % Remove background (now labeled as 0) from list
    nLabels = length(wsLabelList);
    
    tmpBlocks(block).nLabels = nLabels;         % Store for later
    tmpBlocks(block).wsTMLabels = wsTMLabels;   % Store for later
    tmpBlocks(block).wsLabelList = wsLabelList; % Store for later
end
fprintf(['DONE in ' num2str(toc) ' seconds \n']);

%% -- STEP 3: calculate properties of each dot and store them into Dots struct array --
tmpDots = struct;
tmpDot = struct;

% Find intensity of noise in the image (Gmode),
% as most common pixel intensity other than zero.
% Dotfinder will search only above the noise intensity level
% up to the maximum intensity in the signal (Gmax)
% TODO: move Gmode and Gmax calculation within each block to skip processing completely blocks outside of the mask
Gmode = double(mode(Post(Post>0)));
Gmax = double(max(Post(Post>0)));
Settings.dotfinder.Gmode = Gmode;      % added the saving of Gmode to check if Gmode is not too high. 1/18/2010
Settings.dotfinder.Gmax = Gmax;        % Gmax for scaling the image if you didnt use the full bitdepth when creating tif stacks for 'I'

txtBar('Accumulating properties for each detected object... ');
tic;
tmpDots.Pos=[0,0,0];
tmpDots.Vox.Pos=[0,0,0];
tmpDots.Vox.Ind=[0,0,0];
tmpDots.Vol = 0;
tmpDots.ITMax = 0;
tmpDots.ItSum = 0;
tmpDots.Vox.RawBright = 0;
tmpDots.Vox.IT = 0;
tmpDots.MeanBright = 0;

for block = 1:(NumBx*NumBy*NumBz)
    txtBar(100*block/(NumBz*NumBx*NumBy));
    
    ys = tmpBlocks(block).sizeIgm(1);             % get stored values
    xs = tmpBlocks(block).sizeIgm(2);             % get stored values
    zs = tmpBlocks(block).sizeIgm(3);             % get stored values
    yStart = tmpBlocks(block).startPos(1);        % get stored values
    xStart = tmpBlocks(block).startPos(2);        % get stored values
    zStart = tmpBlocks(block).startPos(3);        % get stored values
    yEnd = tmpBlocks(block).endPos(1);            % get stored values
    xEnd = tmpBlocks(block).endPos(2);            % get stored values
    zEnd = tmpBlocks(block).endPos(3);            % get stored values
    peakMap = tmpBlocks(block).peakMap;           % get stored values
    wsTMLabels = tmpBlocks(block).wsTMLabels;     % get stored values
    wsLabelList = tmpBlocks(block).wsLabelList;   % get stored values
    thresholdMap = tmpBlocks(block).thresholdMap; % get stored values
    nLabels = tmpBlocks(block).nLabels;           % get stored values
    Igm = single(Post(yStart:yEnd,xStart:xEnd,zStart:zEnd)); % get stored values
    
    for i = 1:nLabels
        peakIndex = find(wsTMLabels==wsLabelList(i) & peakMap>0); % this line adjusted for watershed HO 6/7/2010
        thresholdPeak = thresholdMap(peakIndex);
        nPeaks = numel(peakIndex);
        
        [yPeak, xPeak, zPeak] = ind2sub([ys xs zs], peakIndex);
        
        if nPeaks == 1
            %remove all dots found in buffer region instead of those found in the OUTER HALF of buffer region 1/5/2010 HO
            if  (yPeak <= blockBuffer && yStart > 1) ||...
                    (xPeak <= blockBuffer && xStart > 1) ||...
                    (zPeak <= blockBuffer && zStart > 1) ||...
                    (ys-yPeak < blockBuffer && yEnd < Rys) ||...
                    (xs-xPeak < blockBuffer && xEnd < Rxs) ||...
                    (zs-zPeak < blockBuffer && zEnd < Rzs) ||...
                    (thresholdPeak < minFinalDotITMax) %HO 2/8/2011 added excluding dots that did not reach minFinalDotITMax criterion
                %disp('dot in buffer region');
            else
                % Changed to define the cutOff range by yourself (upper and lower-bound rather than just defining the upper bound previously) HO 2/12/2010
                PossibleMaxITMax = (Gmax - Gmode)/thresholdStep; %HO 2/12/2010 AAB 05/
                thresholdPeak = double(thresholdPeak); %HO 3/1/2010 if thresholdPeak is uint8, the next line always spit out zero, so thresholdPeak must be double.
                cutOff = (peakCutoffUpperBound - (peakCutoffUpperBound-peakCutoffLowerBound)*thresholdPeak/PossibleMaxITMax)*thresholdPeak; %HO 2/12/2010
                thresholdPeak = uint8(thresholdPeak); %HO 3/1/2010 convert thresholdPeak back to uint8.
                contourIndex = find(wsTMLabels==wsLabelList(i) & thresholdMap>=cutOff); %this line adjusted for watershed HO 6/7/2010
                
                if numel(contourIndex) >= minFinalDotSize %HO 2/15/2011 added excluding dots that did not reach minFinalDotSize criterion
                    %2/8/2011 HO added this if-end loop to impose maxDotSize limit
                    %to watershed-separated individual dots because I changed max
                    %dot size limitation for multi-peak object during iterative
                    %thresholding to maxDotSize*NumPeak (see line 193). This way,
                    %you prevent individual dot from becoming too large.
                    if numel(contourIndex) > maxDotSize
                        ITList = thresholdMap(contourIndex);
                        NewcutOff = thresholdPeak+1;
                        VoxSum = 0;
                        while VoxSum < maxDotSize
                            NewcutOff = NewcutOff-1;
                            VoxSum = length(find(ITList>=NewcutOff));
                        end
                        cutOff = NewcutOff + 1;
                        contourIndex = find(wsTMLabels==wsLabelList(i) & thresholdMap>=cutOff);
                    end
                    
                    [yContour, xContour, zContour] = ind2sub([ys xs zs], contourIndex);
                    
                    %LDS figure out why X and Y are stored inverted, Y first then X
                    tmpDot.Pos = [yPeak+yStart-1, xPeak+xStart-1, zPeak+zStart-1];
                    tmpDot.Vox.Pos = [yContour+yStart-1, xContour+xStart-1, zContour+zStart-1];
                    tmpDot.Vox.Ind = sub2ind([Rys Rxs Rzs], tmpDot.Vox.Pos(:,1), tmpDot.Vox.Pos(:,2), tmpDot.Vox.Pos(:,3));
                    tmpDot.Vol = numel(contourIndex);
                    tmpDot.ITMax = thresholdPeak;
                    tmpDot.ItSum = sum(thresholdMap(contourIndex));
                    tmpDot.Vox.RawBright = Igm(contourIndex);
                    tmpDot.Vox.IT = thresholdMap(contourIndex); %save also the iteration of each voxel 2/9/2011 HO
                    tmpDot.MeanBright = mean(Igm(contourIndex));
                    tmpDots(end+1) = tmpDot; % LDS figure out why this does not work with parfor
                    
                end % if dot size bigger than min dot size
            end % if dot does not reside in the border region between blocks
        end  % if only 1 peak found
    end  % for all labels
end
tmpDots(1)=[]; % Remove first tmpDot used for initialization of the struct array

Dots = struct;
% Convert tmpDots into the deprecated "Dots" structure
for i=1:numel(tmpDots)
    Dots.Pos(i,:) = tmpDots(i).Pos;
    Dots.Vox(i).Pos = tmpDots(i).Vox.Pos;
    Dots.Vox(i).Ind = tmpDots(i).Vox.Ind;
    Dots.Vol(i) = tmpDots(i).Vol;
    Dots.ITMax(i) = tmpDots(i).ITMax;
    Dots.ItSum(i) = tmpDots(i).ItSum;
    Dots.Vox(i).RawBright = tmpDots(i).Vox.RawBright;
    Dots.Vox(i).IT = tmpDots(i).Vox.IT;
    Dots.MeanBright(i) = tmpDots(i).MeanBright;
end
Dots.ImSize = [Rys Rxs Rzs];
Dots.Num = size(Dots.Pos,1);
txtBar(['DONE in ' num2str(toc) ' seconds']);

%%
txtBar('Resolving duplicate objects in the overlapping regions of search blocks... ');
tic;
% -- STEP 4: resolve dots spanning across border region of analyzed blocks --
% Some voxels could be shared by multiple dots because of the overlapping
% search blocks approach in Step#1 and Step#2. This happens for voxels at
% the border lines of processing blocks. Disambiguate those voxels by
% re-assigning them only to the dot that has most voxels in the area.

VoxMap = uint8(zeros(Dots.ImSize)); % Map of whether a voxel belongs to a dot in Dots (1) or not (0)
VoxIDMap = zeros(Dots.ImSize); % Map of the ownerd of each voxel (dot IDs)
[ys, xs, zs] = size(VoxMap);
TotalNumOverlapDots = 0;
TotalNumOverlapVoxs = 0;
DotsToDelete = [];

for i = 1:Dots.Num
    txtBar(100*(i/Dots.Num));
    % Mark voxels belonging to this dot as overlapping if in VoxMap those
    % voxels were already assigned to another dot (value in VoxMap == 1)
    OverlapVoxInd = find((VoxMap(Dots.Vox(i).Ind) > 0));
    
    % Resolve overlapping voxels of current dot one-by-one because 
    % they might overlap with different dot IDs
    if ~isempty(OverlapVoxInd)
        TotalNumOverlapDots = TotalNumOverlapDots + 1;
        TotalNumOverlapVoxs = TotalNumOverlapVoxs + length(OverlapVoxInd);
        OverlapVoxInds = Dots.Vox(i).Ind(OverlapVoxInd);
        OverlapVoxIDs = VoxIDMap(OverlapVoxInds);

        VoxMap(Dots.Vox(i).Ind) = 1; % Mark "1" voxels in the image if they belong to the current dot
        VoxIDMap(Dots.Vox(i).Ind) = i; % Mark current dot ID# as the owner of those voxels
        VoxIDMap(Dots.Vox(i).Ind(OverlapVoxInd)) = 0; % Unmark current dot from being the owner of overlapping voxels
        
        % Explore overlapping voxels and assign each one of them either
        % to current dot's ID# or to the overlapping dot's ID#
        % using the same way as filling dot edges of watershed, HO 2/9/2011
        [OverlapVoxY, OverlapVoxX, OverlapVoxZ] = ind2sub(size(VoxMap), OverlapVoxInds); % Find coordinates of overlapping dots
        for k = 1:length(OverlapVoxInds)
            SurroudingIDs =  VoxIDMap(max(1,OverlapVoxY(k)-1):min(ys,OverlapVoxY(k)+1), max(1,OverlapVoxX(k)-1):min(xs,OverlapVoxX(k)+1), max(1,OverlapVoxZ(k)-1):min(zs,OverlapVoxZ(k)+1));
            SurroudingIDs(isnan(SurroudingIDs)) = 0 ; % Convert NaN to 0 if present in the matrix LDS fix 7-25-2017

            % Decide which of the 2 dots fighting over the overlapping voxel owns most of the surrounding voxels.
            WinningID = mode(SurroudingIDs((SurroudingIDs==i) | (SurroudingIDs==OverlapVoxIDs(k))));
            if WinningID == i
                LosingID = OverlapVoxIDs(k);
            else
                LosingID = i;
            end
            
            VoxIDMap(OverlapVoxInds(k)) = WinningID; % Assign voxels to winning dot ID#
            LosingVox = find(Dots.Vox(LosingID).Ind == OverlapVoxInds(k)); % Remove losing voxels from losing dot ID#
            Dots.Vox(LosingID).Pos(LosingVox,:) = [];
            Dots.Vox(LosingID).Ind(LosingVox) = [];
            Dots.Vox(LosingID).RawBright(LosingVox) = [];
            Dots.Vox(LosingID).IT(LosingVox) = [];
            Dots.Vol(LosingID) = Dots.Vol(LosingID) - 1;
            
            % If losing dot has no more voxels left, then mark this dot
            % for deletion, otherwise recalculate average values of ITMax, 
            % ItSum, MeanBright for the losing dot according to voxels left
            if numel(Dots.Vox(LosingID).IT) == 0
                DotsToDelete(numel(DotsToDelete)+1) = LosingID;
            else
                Dots.ITMax(LosingID) = max(Dots.Vox(LosingID).IT);
                Dots.ItSum(LosingID) = sum(Dots.Vox(LosingID).IT);
                Dots.MeanBright(LosingID) = mean(Dots.Vox(LosingID).RawBright);
            end
        end
    else
        VoxMap(Dots.Vox(i).Ind) = 1;
        VoxIDMap(Dots.Vox(i).Ind) = i;
    end
end

% Delete dots that have no more voxels left after the previous pruning
DotsToDelete = sort(DotsToDelete,'descend'); % Iterate dots ID# from bigger to smaller to not mess up order of remaining dots in the array
for i = 1:numel(DotsToDelete)
    Dots.Pos(DotsToDelete(i), :) = [];
    Dots.Vox(DotsToDelete(i)) = [];
    Dots.Vol(DotsToDelete(i)) = [];
    Dots.ITMax(DotsToDelete(i)) = [];
    Dots.ItSum(DotsToDelete(i)) = [];
    Dots.MeanBright(DotsToDelete(i)) = [];
end
Dots.Num = numel(Dots.Vox); % Recalculate total number of dots

Dots.TotalNumOverlapDots = TotalNumOverlapDots;
Dots.TotalNumOverlapVoxs = TotalNumOverlapVoxs;
txtBar(['DONE in ' num2str(toc) ' seconds']);

clear Bx* By* Bz* CC contour* cutOff debug Gm* i j k Ig* labels Losing*
clear max* n* Num* Overlap* p peak* Possible* Rxs Rys Rzs Surrouding*
clear temp* tmp* threshold* Total* Tx* Ty* Tz* v Vox* Winning* ws* x* y* z* itMin DotsToDelete
clear block blockBuffer blockSize minDotSize minFinalDotITMax minFinalDotSize  MultiPeakDotSizeCorrectionFactor
end