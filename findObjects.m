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

function Dots = findObjects(Post, Settings)

% Retrieve parameters to use from Settings
blockSize        = Settings.objfinder.blockSize;
blockBuffer      = Settings.objfinder.blockBuffer;
thresholdStep    = Settings.objfinder.thresholdStep;
maxDotSize       = Settings.objfinder.maxDotSize;
minDotSize       = Settings.objfinder.minDotSize;
itMin            = Settings.objfinder.itMin;
minFinalDotITMax = Settings.objfinder.minFinalDotITMax;
blockSearch      = Settings.objfinder.blockSearch;
minIntensity     = Settings.objfinder.minIntensity;

% Calculate the block size to Subsample the volume
if blockSearch
    if size(Post,2)>blockSize
        NumBx=round(size(Post,2)/blockSize);
        Bxc=fix(size(Post,2)/NumBx);
    else
        NumBx=1;
        Bxc=size(Post,2);
    end
    
    if size(Post,1)>blockSize
        NumBy=round(size(Post,1)/blockSize);
        Byc=fix(size(Post,1)/NumBy);
    else
        NumBy=1;
        Byc=size(Post,1);
    end
    
    if size(Post,3)>blockSize
        NumBz=round(size(Post,3)/blockSize);
        Bzc=fix(size(Post,3)/NumBz);
    else
        NumBz=1;
        Bzc=size(Post,3);
    end
else
    % Just one block
	NumBx=1;
    NumBy=1;
    NumBz=1;
    Bxc=size(Post,2);
    Byc=size(Post,1);
    Bzc=size(Post,3);
end

%% -- STEP 1: divide the image volume into searching blocks for multi-threading
clear Blocks;
tic;
fprintf('Dividing image volume into blocks... ');
Blocks(NumBx * NumBy * NumBz) = struct;

% Split full image (Post) into blocks
for block = 1:(NumBx*NumBy*NumBz)
    [Blocks(block).Bx, Blocks(block).By, Blocks(block).Bz] = ind2sub([NumBx, NumBy, NumBz], block);
    %disp(['current block = Bx:' num2str(Bx) ', By:' num2str(By) ', Bz:' num2str(Bz)]);

    %Find real territory
    Txstart=(Blocks(block).Bx-1)*Bxc+1;
    Tystart=(Blocks(block).By-1)*Byc+1;
    Tzstart=(Blocks(block).Bz-1)*Bzc+1;

    if Byc, Tyend=Blocks(block).By*Byc; else, Tyend=size(Post,1); end
    if Bxc, Txend=Blocks(block).Bx*Bxc; else, Txend=size(Post,2); end
    if Bzc, Tzend=Blocks(block).Bz*Bzc; else, Tzend=size(Post,3); end

    % Find buffered Borders (if last block, extend to image borders)
    yStart                  = Tystart-blockBuffer;
    yStart(yStart<1)        = 1;
    yEnd                    = Tyend+blockBuffer;
    yEnd(yEnd>size(Post,1)) = size(Post,1);
    xStart                  = Txstart-blockBuffer;
    xStart(xStart<1)        = 1;
    xEnd                    = Txend+blockBuffer;
    xEnd(xEnd>size(Post,2)) = size(Post,2);
    zStart                  = Tzstart-blockBuffer;
    zStart(zStart<1)        = 1;
    zEnd                    = Tzend+blockBuffer;
    zEnd(zEnd>size(Post,3)) = size(Post,3);

    % Slice the raw image into the block of interest (Igm)
    Blocks(block).Igm           = Post(yStart:yEnd,xStart:xEnd,zStart:zEnd);
    
    % Search only between max intensity (Gmax) and noise intensity level (Gmode) found in each block
    Blocks(block).Gmode         = mode(Blocks(block).Igm(Blocks(block).Igm>0)); % Most common intensity found in the block (noise level, excluding zero)
    Blocks(block).Gmax          = max(Blocks(block).Igm(:));
    Blocks(block).sizeIgm       = size(Blocks(block).Igm);

    Blocks(block).peakMap       = zeros(Blocks(block).sizeIgm(1),Blocks(block).sizeIgm(2),Blocks(block).sizeIgm(3),'uint8'); % Initialize matrix to map peaks found
    Blocks(block).thresholdMap  = Blocks(block).peakMap; % Initialize matrix to sum passed thresholds

    % Make sure Gmax can be divided by the stepping size of thresholdStep
    if mod(Blocks(block).Gmax, thresholdStep) ~= mod(Blocks(block).Gmode+1, thresholdStep)
        Blocks(block).Gmax      = Blocks(block).Gmax+1;
    end

    Blocks(block).startPos      = [yStart, xStart, zStart]; % Store for later
    Blocks(block).endPos        = [yEnd, xEnd, zEnd];         % Store for later
    Blocks(block).Igl           = [];
    Blocks(block).wsTMLabels    = [];
	Blocks(block).wsLabelList   = [];
	Blocks(block).nLabels       = 0;

end
fprintf(['DONE in ' num2str(toc) ' seconds \n']);
clear xStart xEnd yStart yEnd zStart zEnd T*

%% -- STEP 2: scan the volume and find areas crossing local contrast threshold with a progressively coarser intensity filter --
tic;
fprintf('Searching candidate objects using multi-threaded iterarive threshold ... ');

parfor block = 1:(NumBx*NumBy*NumBz)
    % Scan volume to find areas crossing contrast threshold with progressively coarser intensity filter
    for i = Blocks(block).Gmax:-thresholdStep:ceil(Blocks(block).Gmode * minIntensity)+1 % Iterate from Gmax to noise level (Gmode+1) within each block
        
        % Label all areas in the block (Igl) that crosses the intensity threshold "i"
        %[Igl,labels] = bwlabeln(Igm>i,6); % shorter but slower
        CC = bwconncomp(Blocks(block).Igm > i,6); % 10 percent faster
        labels = CC.NumObjects;
        Blocks(block).Igl = labelmatrix(CC);
        
        if labels == 0
            continue;
        elseif labels <= 1
            labels = 2;
        end
        if labels < 65536
            Blocks(block).Igl=uint16(Blocks(block).Igl);
        end % Reduce bitdepth if possible
        nPixel = hist(Blocks(block).Igl(Blocks(block).Igl>0), 1:labels);

        % Find peak location in each labeled object and check object size
        for p=1:labels
            pixelIndex = find(Blocks(block).Igl==p);
            
            if (nPixel(p) < maxDotSize) && (nPixel(p) > 3)
                if sum(Blocks(block).peakMap(pixelIndex))== 0
                    % limit one peak (peakIndex) per labeled area (where Igl==p)
                    peakValue = max(Blocks(block).Igm(pixelIndex));
                    peakIndex = find(Blocks(block).Igl==p & Blocks(block).Igm==peakValue);
                    if numel(peakIndex) > 1
                        peakIndex = peakIndex(round(numel(peakIndex)/2));
                    end
                    Blocks(block).peakMap(peakIndex) = 1;
                end
            else
                Blocks(block).Igl(pixelIndex)=0;
            end
        end
        Blocks(block).thresholdMap(Blocks(block).Igl>0) = Blocks(block).thresholdMap(Blocks(block).Igl>0)+1; % +1 to all voxels that passed this iteration
    end % for all intensities

    Blocks(block).thresholdMap(Blocks(block).thresholdMap<itMin) = 0; % only objects with more than 2 IT pass are analyzed, I set to 2 for now because you want to save voxels of IT = 2 for the dot of ITmax = 4, for example. HO 2/8/2011
    Blocks(block).wsTMLabels    = Blocks(block).Igl;                  % wsTMLabels = block volume labeled with same numbers for the voxels that belong to same object
    Blocks(block).wsLabelList   = unique(Blocks(block).wsTMLabels);   % wsLabelList = unique labels list used to label the block volume 
    Blocks(block).nLabels       = numel(Blocks(block).wsLabelList);   % nLabels = number of labels = number of objects detected
end
fprintf(['DONE in ' num2str(toc) ' seconds \n']);

%% -- STEP 3: Find the countour of each dot and split it using watershed if multiple peaks are found within the same dot --

tic;
if Settings.objfinder.watershed
    fprintf('Split multi-peak objects using multi-threaded watershed segmentation ... ');
    use_watershed = true;
else
    fprintf('Watershed DISABLED by user, collecting candidate objects... ');
    use_watershed = false;
end

parfor block = 1:(NumBx*NumBy*NumBz)
    % Scan again all the blocks
    ys = Blocks(block).sizeIgm(1);  % retrieve values
    xs = Blocks(block).sizeIgm(2);  % retrieve values
    zs = Blocks(block).sizeIgm(3);  % retrieve values
    
    wsThresholdMapBin = uint8(Blocks(block).thresholdMap>0);         % binary map of threshold
    wsThresholdMapBinOpen = imdilate(wsThresholdMapBin, ones(3,3,3));% dilate Bin map with a 3x3x3 kernel (dilated perimeter acts like ridges between background and ROIs)
    wsThresholdMapComp = imcomplement(Blocks(block).thresholdMap);   % complement (invert) image. Required because watershed() separate holes, not mountains. imcomplement creates complement using the entire range of the class, so for uint8, 0 becomes 255 and 255 becomes 0, but for double 0 becomes 1 and 255 becomes -254.
    wsTMMod = wsThresholdMapComp.*wsThresholdMapBinOpen;             % Force background outside of dilated region to 0, and leaves walls of 255 between puncta and background.
    
    if use_watershed
        wsTMLabels = watershed(wsTMMod, 6);                          % 6 voxel connectivity watershed, this will fill background with 1, ridges with 0 and puncta with 2,3,4,... in double format
    else
        wsTMMod = Blocks(block).thresholdMap;                        % 6 voxel connectivity without watershed on the original threshold map.        
        wsTMLabels = bwlabeln(wsTMMod,6);
    end
    
    wsBackgroundLabel = mode(double(wsTMLabels(:)));                 % calculate background level
    wsTMLabels(wsTMLabels == wsBackgroundLabel) = 0;                 % seems that sometimes Background can get into puncta... so the next line was not good enough to remove all the background labels.
    wsTMLabels= double(wsTMLabels).*double(wsThresholdMapBin);       % masking out non-puncta voxels, this makes background and dilated voxels to 0. This also prevents trough voxels from being added back somehow with background. HO 6/4/2010
    wsTMLZeros= find(wsTMLabels==0 & Blocks(block).thresholdMap>0);  % find zeros of watersheds inside of thresholdmap (add back the zero ridges in thresholdMap to their most similar neighbors)
    
    if ~isempty(wsTMLZeros) % if exist zeros in the map
        [wsTMLZerosY, wsTMLZerosX, wsTMLZerosZ] = ind2sub(size(Blocks(block).thresholdMap),wsTMLZeros); %6/4/2010 HO
        for j = 1:length(wsTMLZeros) % create a dilated matrix to examine neighbor connectivity around the zero position
            tempZMID =  wsTMLabels(max(1,wsTMLZerosY(j)-1):min(ys,wsTMLZerosY(j)+1), max(1,wsTMLZerosX(j)-1):min(xs,wsTMLZerosX(j)+1), max(1,wsTMLZerosZ(j)-1):min(zs,wsTMLZerosZ(j)+1)); %HO 6/4/2010
            nZeroID = mode(tempZMID(tempZMID~=0)); % find most common neighbor value (watershed) not including zero
            wsTMLabels(wsTMLZeros(j)) = nZeroID;   % re-define zero with new watershed ID (this process will act similar to watershed by making new neighboring voxels feed into the decision of subsequent zero voxels)
        end
    end
    
    wsTMLabels                  = uint16(wsTMLabels);
    wsLabelList                 = unique(wsTMLabels);
    wsLabelList(1)              = []; % Remove background (labeled 0)
    nLabels                     = length(wsLabelList);
    
    Blocks(block).nLabels       = nLabels;     % Store for later
    Blocks(block).wsTMLabels    = wsTMLabels;  % Store for later
    Blocks(block).wsLabelList   = wsLabelList; % Store for later
end
fprintf(['DONE in ' num2str(toc) ' seconds \n']);

%% -- STEP 4: calculate dots properties and store into a struct array --
tic;
fprintf('Accumulating properties for each detected object... ');

tmpDot = struct;
tmpDot.Pos=[0,0,0];
tmpDot.Vox.Pos=[0,0,0];
tmpDot.Vox.Ind=[0,0,0];
tmpDot.Vol = 0;
tmpDot.ITMax = 0;
tmpDot.ItSum = 0;
tmpDot.Vox.RawBright = 0;
tmpDot.Vox.IT = 0;
tmpDot.MeanBright = 0;

%clear tmpDots
%tmpDots(sum([Blocks.nLabels])) = struct(tmpDot); % Preallocate max number of dots
tmpDots = struct(tmpDot);
tmpDotNum = 0;

for block = 1:(NumBx*NumBy*NumBz)
    wsTMLabels  = Blocks(block).wsTMLabels;
    wsLabelList = Blocks(block).wsLabelList;
    nLabels     = Blocks(block).nLabels;
    
    for i = 1:nLabels
        peakIndex = find( (wsTMLabels==wsLabelList(i)) & (Blocks(block).peakMap>0) ); % this line adjusted for watershed HO 6/7/2010
        thresholdPeak = Blocks(block).thresholdMap(peakIndex);  
        nPeaks = numel(peakIndex);                

        if nPeaks > 1
            % In case of multiple peaks, get the peak with max threshold
            peakIndex = peakIndex(find(thresholdPeak==max(thresholdPeak),1));
            thresholdPeak = max(thresholdPeak);
            nPeaks = numel(peakIndex);
        else
            %disp(['block = ' num2str(block)]);
            %disp(['i = ' num2str(i)]);
            %disp(['peaks  =' num2str(nPeaks)]);
            %disp(['index = ' num2str(peakIndex)]);
            %disp(['threshold = ' num2str(thresholdPeak)]);
        end
        
        if (nPeaks ~=1) || (thresholdPeak < minFinalDotITMax)
            % If watershed was used there should not be any more object with multiple peaks
            continue;
        end
        
        [yPeak, xPeak, zPeak] = ind2sub(Blocks(block).sizeIgm, peakIndex);

        
        % Accumulate only if object size is within minDotSize/maxDotSize
        contourIndex = find(wsTMLabels==wsLabelList(i)); % adjusted for watershed
        
        if (numel(contourIndex) >= minDotSize) && (numel(contourIndex) <= maxDotSize)
            [yContour, xContour, zContour] = ind2sub(Blocks(block).sizeIgm, contourIndex);

            tmpDot.Pos          = [yPeak+Blocks(block).startPos(1)-1,    xPeak+Blocks(block).startPos(2)-1,    zPeak+Blocks(block).startPos(3)-1];
            tmpDot.Vox.Pos      = [yContour+Blocks(block).startPos(1)-1, xContour+Blocks(block).startPos(2)-1, zContour+Blocks(block).startPos(3)-1];
            tmpDot.Vox.Ind      = sub2ind([size(Post,1) size(Post,2) size(Post,3)], tmpDot.Vox.Pos(:,1), tmpDot.Vox.Pos(:,2), tmpDot.Vox.Pos(:,3));
            tmpDot.Vol          = numel(contourIndex);
            tmpDot.ITMax        = thresholdPeak;
            tmpDot.ItSum        = sum(Blocks(block).thresholdMap(contourIndex));
            tmpDot.Vox.RawBright= Blocks(block).Igm(contourIndex);
            tmpDot.Vox.IT       = Blocks(block).thresholdMap(contourIndex);
            tmpDot.MeanBright   = mean(Blocks(block).Igm(contourIndex));
            %tmpDotNum = sum([Blocks(1:block).nLabels]) - Blocks(block).nLabels + i; % Work on preallocated max number of dots
            tmpDotNum           = tmpDotNum + 1; % Work on non-preallocated dots
            tmpDots(tmpDotNum)  = tmpDot;
        end
    end
end
fprintf(['DONE in ' num2str(toc) ' seconds \n']);

%% -- STEP 5: resolve empty dots and dots in border between blocks --
% Some voxels could be shared by multiple dots because of the overlapping
% search blocks approach in Step#1 and Step#2. This happens for voxels at
% the border lines of processing blocks. Disambiguate those voxels by
% re-assigning them only to the dot that has most voxels in the area.
tic;
fprintf('Resolving duplicate objects in the overlapping regions of search blocks... ');

VoxMap = uint8(zeros(size(Post)));  % Map of whether a given voxel belongs to an object (value = 1) or not (values = 0)
VoxIDMap = zeros(size(Post));       % Map of the owners of each voxel (dot IDs)
[ys, xs, zs] = size(VoxMap);        % Size of the maps
TotalNumOverlapDots = 0;            % Number of overlapping Dots
TotalNumOverlapVoxs = 0;            % Number of overlapping Voxels

% Delete empty dots from previous step
%for i = numel(tmpDots):-1:1
%    if isempty(tmpDots(i).Vol) || (tmpDots(i).Vol == 0) 
%        tmpDots(i) = [];
%    end
%end

for i = 1:numel(tmpDots)
    % Mark voxels belonging to this dot as overlapping if in VoxMap those
    % voxels were already assigned to another dot (value in VoxMap == 1)
    OverlapVoxInd = find((VoxMap(tmpDots(i).Vox.Ind) > 0));

    % Resolve overlapping voxels of current dot one-by-one because
    % they might overlap not all with a unique other dot ID
    if isempty(OverlapVoxInd)
        % Mark voxels belonging to this object as taken (value = 1)
        VoxMap(tmpDots(i).Vox.Ind) = 1;
        VoxIDMap(tmpDots(i).Vox.Ind) = i;
    else
        % Resolve conflict because some voxels are taken by another object
        TotalNumOverlapDots = TotalNumOverlapDots + 1;
        TotalNumOverlapVoxs = TotalNumOverlapVoxs + length(OverlapVoxInd);
        OverlapVoxInds = tmpDots(i).Vox.Ind(OverlapVoxInd);
        OverlapVoxIDs = VoxIDMap(OverlapVoxInds);

        VoxMap(tmpDots(i).Vox.Ind) = 1;                     % Mark "1" voxels in the image if they belong to the current dot
        VoxIDMap(tmpDots(i).Vox.Ind) = i;                   % Mark current dot ID# as the owner of those voxels
        VoxIDMap(tmpDots(i).Vox.Ind(OverlapVoxInd)) = 0;    % Unmark current dot from being the owner of overlapping voxels

        % loop overlapping voxels and assign them either to current dot ID or to the overlapping dot ID
        [OverlapVoxY, OverlapVoxX, OverlapVoxZ] = ind2sub(size(VoxMap), OverlapVoxInds); % Find XYZ coordinates of overlapping dots
        for k = 1:length(OverlapVoxInds)
            SurroudingIDs =  VoxIDMap(max(1,OverlapVoxY(k)-1):min(ys,OverlapVoxY(k)+1), max(1,OverlapVoxX(k)-1):min(xs,OverlapVoxX(k)+1), max(1,OverlapVoxZ(k)-1):min(zs,OverlapVoxZ(k)+1));
            SurroudingIDs(isnan(SurroudingIDs)) = 0 ; % Convert NaN to 0 if present in the matrix LDS fix 7-25-2017

            % Decide winning object as the one owning most of the surrounding voxels around the ovelapping voxel.
            WinningID = mode(SurroudingIDs((SurroudingIDs==i) | (SurroudingIDs==OverlapVoxIDs(k))));
            if WinningID == i
                LosingID = OverlapVoxIDs(k);
            else
                LosingID = i;
            end
            
            VoxIDMap(OverlapVoxInds(k)) = WinningID;    % Assign voxels to winning dot ID#
            if ~isnan(LosingID)
                LosingVox = find(tmpDots(LosingID).Vox.Ind == OverlapVoxInds(k)); % Remove losing voxels from losing dot ID#
                tmpDots(LosingID).Vox.Pos(LosingVox,:) = [];
                tmpDots(LosingID).Vox.Ind(LosingVox) = [];
                tmpDots(LosingID).Vox.RawBright(LosingVox) = [];
                tmpDots(LosingID).Vox.IT(LosingVox) = [];
                tmpDots(LosingID).Vol = tmpDots(LosingID).Vol - 1;

                % If losing dot has still voxels left, recalculate properties
                if numel(tmpDots(LosingID).Vox.IT) > 0
                    tmpDots(LosingID).ITMax = max(tmpDots(LosingID).Vox.IT);
                    tmpDots(LosingID).ItSum = sum(tmpDots(LosingID).Vox.IT);
                    tmpDots(LosingID).MeanBright = mean(tmpDots(LosingID).Vox.RawBright);
                end
            end
        end
    end
end

% Delete dots that have no more voxels left after the previous pruning
for i = numel(tmpDots):-1:1
    if numel(tmpDots(i).Vox.IT) == 0
        tmpDots(i) = [];
    end
end

% Convert tmpDots into the old "Dots" structure 
% (TODO make this structure deprecated and return directly tmpDots)
Dots = struct; 
for i = numel(tmpDots):-1:1
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

Dots.ImSize = [size(Post,1) size(Post,2) size(Post,3)];
Dots.Num = numel(Dots.Vox); % Recalculate total number of dots
fprintf(['DONE in ' num2str(toc) ' seconds \n']);

clear B* CC contour* cutOff debug Gm* i j k Ig* labels Losing* ans
clear max* n* Num* Overlap* p peak* Possible* size(Post,2) size(Post,1) size(Post,3) Surrouding*
clear tmp* threshold* Total* T* v Vox* Winning* ws* x* y* z* itMin DotsToDelete
clear block blockBuffer blockSize minDotSize minFinalDotITMax minDotSize  MultiPeakDotSizeCorrectionFactor
end
