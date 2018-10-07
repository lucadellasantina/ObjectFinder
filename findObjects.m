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

function [Dots, Time] = findObjects(Post, Settings)

% Retrieve parameters to use from Settings
Time             = 0;
blockSize        = Settings.objfinder.blockSize;
blockBuffer      = Settings.objfinder.blockBuffer;
maxDotSize       = Settings.objfinder.maxDotSize;
minDotSize       = Settings.objfinder.minDotSize;
itMin            = Settings.objfinder.itMin;
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
    Blocks(block).sizeIgm       = [size(Blocks(block).Igm,1), size(Blocks(block).Igm,2), size(Blocks(block).Igm,3)];

    Blocks(block).peakMap       = zeros(Blocks(block).sizeIgm(1), Blocks(block).sizeIgm(2), Blocks(block).sizeIgm(3),'uint8'); % Initialize matrix to map peaks found
    Blocks(block).thresholdMap  = Blocks(block).peakMap; % Initialize matrix to sum passed thresholds

    Blocks(block).startPos      = [yStart, xStart, zStart]; % Store for later
    Blocks(block).endPos        = [yEnd, xEnd, zEnd];         % Store for later
    Blocks(block).Igl           = [];
    Blocks(block).wsTMLabels    = [];
	Blocks(block).wsLabelList   = [];
	Blocks(block).nLabels       = 0;

end

tmpTime = toc;
fprintf([num2str(NumBx*NumBy*NumBz) ' blocks, DONE in ' num2str(tmpTime) ' seconds \n']);
Time = Time + tmpTime;

clear xStart xEnd yStart yEnd zStart zEnd

%% -- STEP 2: scan the volume and find areas crossing local contrast threshold with a progressively coarser intensity filter --
tic;
fprintf('Searching candidate objects using multi-threaded iterarive threshold ... ');

parfor block = 1:(NumBx*NumBy*NumBz)
    % Scan volume to find areas crossing contrast threshold with progressively coarser intensity filter
    for i = Blocks(block).Gmax:-1:ceil(Blocks(block).Gmode * minIntensity)+1 % Iterate from Gmax to noise level (Gmode+1) within each block
        
        % Label all areas in the block (Igl) that crosses the intensity threshold "i"
        CC = bwconncomp(Blocks(block).Igm > i,6); % 10 percent faster
        labels = CC.NumObjects;
        Blocks(block).Igl = labelmatrix(CC);
        
        if labels == 0
            continue
        elseif labels < 65536
            Blocks(block).Igl=uint16(Blocks(block).Igl); % Lower bitdepth if possible
        end 

        % Find peak location in each labeled object and check object size
        if labels == 1
            nPixel = numel(CC.PixelIdxList{1});
        else
            nPixel = hist(Blocks(block).Igl(Blocks(block).Igl>0), 1:labels);            
        end    

        for p=1:labels
            pixelIndex = CC.PixelIdxList{p}; % 50 percent faster
            
            if (nPixel(p) <= maxDotSize) && (nPixel(p) >= minDotSize)
                if sum(Blocks(block).peakMap(pixelIndex))== 0
                    % limit one peak (peakIndex) per labeled area (where Igl==p)
                    peakValue = max(Blocks(block).Igm(pixelIndex));
                    peakIndex = find(Blocks(block).Igm(pixelIndex)==peakValue); % 50 percent faster
                    if numel(peakIndex) > 1
                        peakIndex = peakIndex(round(numel(peakIndex)/2));
                    end
                    Blocks(block).peakMap(pixelIndex(peakIndex)) = 1;
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

tmpTime = toc;
fprintf(['DONE in ' num2str(toc) ' seconds \n']);
Time = Time + tmpTime;

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

tmpTime = toc;
fprintf(['DONE in ' num2str(tmpTime) ' seconds \n']);
Time = Time + tmpTime;

%% -- STEP 4: calculate dots properties and store into a struct array --
% TODO only thing we need to accumulate is tmpDot.Vox.Ind, all rest of the
% stats can be calculated later after resolving conflicts

tic;
fprintf('Accumulating properties for each detected object... ');

tmpDot               = struct;
tmpDot.Pos           = [0,0,0];
tmpDot.Vox.Pos       = [0,0,0];
tmpDot.Vox.Ind       = [0,0,0];
tmpDot.Vol           = 0;
tmpDot.ITMax         = 0;
tmpDot.ItSum         = 0;
tmpDot.Vox.RawBright = 0;
tmpDot.Vox.IT        = 0;
tmpDot.MeanBright    = 0;

% Count how many valid objects we expect to encounter
NumValidObjects = 0;
for block = 1:(NumBx*NumBy*NumBz)
    VoxelsList  = label2idx(Blocks(block).wsTMLabels);
    for i = 1:Blocks(block).nLabels
        NumVoxels = numel(VoxelsList{i});
        if (NumVoxels >= minDotSize) && (NumVoxels <= maxDotSize)
            NumValidObjects = NumValidObjects+1;
        end
    end
end

if NumValidObjects == 0
    Dots = [];
    return;
else
    tmpDots(NumValidObjects) = tmpDot; % Preallocate tmpDots
end

tmpDotNum            = 0;
for block = 1:(NumBx*NumBy*NumBz)
    VoxelsList  = label2idx(Blocks(block).wsTMLabels);    

    for i = 1:Blocks(block).nLabels
        Voxels = VoxelsList{i};
        
        % Accumulate only if object size is within minDotSize/maxDotSize        
        if (numel(Voxels) >= minDotSize) && (numel(Voxels) <= maxDotSize)
            peakIndex           = Voxels(Blocks(block).peakMap(Voxels)>0);
            if isempty(peakIndex)
                continue % There is no peak for the object (i.e. flat intensity)
            else               
                peakIndex           = peakIndex(1); % Make sure there is only one peak at this stage
            end
            
             [yPeak,xPeak,zPeak] = ind2sub(Blocks(block).sizeIgm, peakIndex);
             [yPos, xPos, zPos]  = ind2sub(Blocks(block).sizeIgm, Voxels);             
             
             tmpDot.Pos          = [yPeak+Blocks(block).startPos(1)-1, xPeak+Blocks(block).startPos(2)-1, zPeak+Blocks(block).startPos(3)-1];
             tmpDot.Vox.Pos      = [yPos+Blocks(block).startPos(1)-1, xPos+Blocks(block).startPos(2)-1, zPos+Blocks(block).startPos(3)-1];
             tmpDot.Vox.Ind      = sub2ind([size(Post,1) size(Post,2) size(Post,3)], tmpDot.Vox.Pos(:,1), tmpDot.Vox.Pos(:,2), tmpDot.Vox.Pos(:,3));
             tmpDot.Vox.RawBright= Blocks(block).Igm(Voxels);
             tmpDot.Vol          = numel(Voxels);
             tmpDot.Vox.IT       = Blocks(block).thresholdMap(Voxels);

             tmpDotNum           = tmpDotNum + 1;
             tmpDots(tmpDotNum)  = tmpDot;
        end
    end
end

tmpTime = toc;
fprintf(['DONE in ' num2str(tmpTime) ' seconds \n']);
Time = Time + tmpTime;

%% -- STEP 5: resolve empty dots and dots in border between blocks --
% Some voxels could be shared by multiple dots because of the overlapping
% search blocks approach. This happens only for voxels at the border of 
% processing blocks. Disambiguate those voxels by re-assigning them to 
% the bigger contending dot.
%
% Strategy: keep an ongoing map VoxIDMap of which voxels are occupied by
% previously iterated dots, resolve only those conflicting with current dot

tic;
fprintf('Resolving duplicate objects in the overlapping regions of search blocks... ');
VoxIDMap = zeros(size(Post));       % Map of the owners of each voxel (dot IDs)

for i = 1:numel(tmpDots)     
    OverlapVoxIDs = tmpDots(i).Vox.Ind(VoxIDMap(tmpDots(i).Vox.Ind) > 0); % Index of overlapping voxels
    OverlapDotIDs = VoxIDMap(OverlapVoxIDs);                              % Current Owner of voxels
    VoxIDMap(tmpDots(i).Vox.Ind) = i;                                     % Claim current Dot voxels on map
    
    if isempty(OverlapVoxIDs)
        continue; 
    end

    % Resolve by assigning all overlapping voxels to the bigger Dot    
    OverlapDots                           = unique(OverlapDotIDs);
    for k = 1:numel(OverlapDots)
        
        % Decide winner object as the biggest contender of the two
        if tmpDots(i).Vol > tmpDots(OverlapDots(k)).Vol
            Winner                        = i;
            Loser                         = OverlapDots(k);
        else
            Winner                        = OverlapDots(k);
            Loser                         = i;
        end
        % Assign all contended voxels to winner
        ContendedVoxIDs                   = OverlapVoxIDs(OverlapDotIDs==OverlapDots(k));
        VoxIDMap(ContendedVoxIDs)         = Winner;
        
        % Remove voxels from loser
        idx = find(ismember(ContendedVoxIDs, tmpDots(Loser).Vox.Ind));
        tmpDots(Loser).Vox.Pos(idx,:)     = [];
        tmpDots(Loser).Vox.Ind(idx)       = [];
        tmpDots(Loser).Vox.RawBright(idx) = [];
        tmpDots(Loser).Vox.IT(idx)        = [];
        tmpDots(Loser).Vol                = tmpDots(Loser).Vol - numel(idx);
    end
end

tmpTime = toc;
fprintf(['DONE in ' num2str(tmpTime) ' seconds \n']);
Time = Time + tmpTime;

% Accumulate tmpDots with volume>0 into the old "Dots" structure 
tic;
fprintf('Pack detected objects into an easily searchable structure... ');

ValidDots = find([tmpDots.Vol] > 0);
Dots = struct; 
for i = numel(ValidDots):-1:1
    Dots.Pos(i,:)           = tmpDots(ValidDots(i)).Pos;
    Dots.Vox(i).Pos         = tmpDots(ValidDots(i)).Vox.Pos;
    Dots.Vox(i).Ind         = tmpDots(ValidDots(i)).Vox.Ind;
    Dots.Vol(i)             = tmpDots(ValidDots(i)).Vol;
    Dots.Vox(i).RawBright   = tmpDots(ValidDots(i)).Vox.RawBright;
    Dots.Vox(i).IT          = tmpDots(ValidDots(i)).Vox.IT;
	Dots.ITMax(i)           = max(Dots.Vox(i).IT);
    Dots.ItSum(i)           = sum(Dots.Vox(i).IT);
	Dots.MeanBright(i)      = mean(Dots.Vox(i).RawBright);
end

Dots.ImSize = [size(Post,1) size(Post,2) size(Post,3)];
Dots.Num = numel(Dots.Vox); % Recalculate total number of dots
tmpTime = toc;
fprintf(['DONE in ' num2str(tmpTime) ' seconds \n']);

Time = Time + tmpTime;

clear B* CC contour* cutOff debug Gm* i j k Ig* labels Losing* ans NumalidObjects
clear max* n* Num* Overlap* p peak* Possible* size(Post,2) size(Post,1) size(Post,3) Surrouding*
clear tmp* threshold* Total*  v Vox* Winning* ws* x* y* z* itMin DotsToDelete
clear block blockBuffer blockSize minDotSize minDotSize  MultiPeakDotSizeCorrectionFactor
clear ContendedVoxIDs idx Loser Winner minIntensity use_watershed ValidDots blockSearch
end
