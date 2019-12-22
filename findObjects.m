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
% *Find objects using an iterative thresholding approach*

function Dots = findObjects(Post, Settings)
%% -- STEP 1: divide the image volume into searching blocks for multi-threading
tic;
fprintf('Dividing image volume into blocks and estimating noise level... ');
blockSize   = Settings.objfinder.blockSize;
blockBuffer = Settings.objfinder.blockBuffer;
if isfield(Settings.objfinder, 'connectedVoxN')
    connectedVoxN = Settings.objfinder.connectedVoxN;
else
    connectedVoxN = 6; % Deault connectivity 6 directions
end

% Calculate the number of blocks to subsample the image volume
if Settings.objfinder.blockSearch
    NumBx   = max(1, ceil(size(Post,2)/blockSize));
    NumBy   = max(1, ceil(size(Post,1)/blockSize));
    NumBz   = max(1, ceil(size(Post,3)/blockSize));
else
    NumBx   = 1;
    NumBy   = 1;
    NumBz   = 1;
end
Blocks(NumBx * NumBy * NumBz) = struct;

% Split full image (Post) into blocks
for block = 1:(NumBx*NumBy*NumBz)
    [Blocks(block).Bx, Blocks(block).By, Blocks(block).Bz] = ind2sub([NumBx, NumBy, NumBz], block);

    % Find boundary coordinates of block + buffered region
    if Settings.objfinder.blockSearch    
        yStart  = max(1, (Blocks(block).By-1)*blockSize-blockBuffer);
        xStart  = max(1, (Blocks(block).Bx-1)*blockSize-blockBuffer);
        zStart  = max(1, (Blocks(block).Bz-1)*blockSize-blockBuffer);
        yEnd    = min(size(Post,1), Blocks(block).By*blockSize+blockBuffer);
        xEnd	= min(size(Post,2), Blocks(block).Bx*blockSize+blockBuffer);
        zEnd    = min(size(Post,3), Blocks(block).Bz*blockSize+blockBuffer);
    else
        yStart  = 1;
        xStart  = 1;
        zStart  = 1;
        yEnd    = size(Post,1);
        xEnd	= size(Post,2);
        zEnd    = size(Post,3);        
    end
    % Slice the raw image into the block of interest (Igm)
    Blocks(block).Igm           = Post(yStart:yEnd, xStart:xEnd, zStart:zEnd);
    
    % Estimate either local / glocal noise level Gmode according to setting
    switch Settings.objfinder.noiseEstimator
        case'mode'
            % Estimates noise as the most common instensity in the data
            if Settings.objfinder.localNoise                
                % Noise level as the most common intensity found in the block (excluding zero)
                Blocks(block).Gmode     = mode(Blocks(block).Igm(Blocks(block).Igm>0));
            else
                % Noise level as the common intensity found in the entire image (excluding zero)
                Blocks(block).Gmode     = mode(Post(Post>0));
            end
        case 'std'
            % Estimates noise is the variability across intensities in the data
            if Settings.objfinder.localNoise
                Blocks(block).Gmode     = uint8(ceil(std(single(Blocks(block).Igm(:)))));
            else
                Blocks(block).Gmode     = uint8(ceil(std(single(Post(:)))));
            end         
        case 'min'
            % Estimates noise as the absolute minimum intensity in the data
            if Settings.objfinder.localNoise
                Blocks(block).Gmode     = min(Blocks(block).Igm(:));
            else
                Blocks(block).Gmode     = min(Post(:));
            end         
    end
    Blocks(block).Gmax          = max(Blocks(block).Igm(:));
    Blocks(block).sizeIgm       = [size(Blocks(block).Igm,1), size(Blocks(block).Igm,2), size(Blocks(block).Igm,3)];

    Blocks(block).peakMap       = zeros(Blocks(block).sizeIgm(1), Blocks(block).sizeIgm(2), Blocks(block).sizeIgm(3),'uint8'); % Initialize matrix to map peaks found
    Blocks(block).thresholdMap  = Blocks(block).peakMap; % Initialize matrix to sum passed thresholds

    Blocks(block).startPos      = [yStart, xStart, zStart];
    Blocks(block).endPos        = [yEnd, xEnd, zEnd];
    Blocks(block).Igl           = [];
    Blocks(block).wsTMLabels    = [];
	Blocks(block).wsLabelList   = [];
	Blocks(block).nLabels       = 0;
    
%     disp(['current block = Bx:' num2str(Blocks(block).Bx) ', By:' num2str(Blocks(block).By) ', Bz:' num2str(Blocks(block).Bz)]);    
%     disp(['Block coordinates = x:' num2str(xStart) ' : ' num2str(xEnd) ', y:' num2str(yStart) ' : ' num2str(yEnd) ', z:' num2str(zStart) ' : ' num2str(zEnd)]);    
%     disp(['Noise level: ' num2str(Blocks(block).Gmode) ' Max level: ' num2str(Blocks(block).Gmax)]);
end

fprintf([num2str(NumBx*NumBy*NumBz) ' blocks, DONE in ' num2str(toc) ' seconds \n']);

clear xStart xEnd yStart yEnd zStart zEnd

%% -- STEP 2: scan the volume and find areas crossing local contrast threshold with a progressively coarser intensity filter --
tic;
fprintf('Searching candidate objects using multi-threaded iterarive threshold ... ');
maxDotSize       = Settings.objfinder.maxDotSize; 
minDotSize       = Settings.objfinder.minDotSize; 
minIntensity     = Settings.objfinder.minIntensity;

parfor block = 1:(NumBx*NumBy*NumBz)
    % Scan volume to find areas crossing contrast threshold with progressively coarser intensity filter
    % Iterating from Gmax to noise level (Gmode+1) within each block
    for i = Blocks(block).Gmax :-1: ceil(Blocks(block).Gmode * minIntensity)+1 
        
        % Label all areas in the block (Igl) that crosses the intensity "i" 
        % bwconncomp+labelmatrix is ~10% faster than using belabeln
        CC                = bwconncomp(Blocks(block).Igm >= i,connectedVoxN);
        labels            = CC.NumObjects;
        Blocks(block).Igl = labelmatrix(CC);
        
        % Find peak location in each labeled object and check object size
        nPixel = 0; %#ok needed to avoid parfor warning of not-initialized
        switch labels
            case 0,     continue
            case 1,     nPixel = numel(CC.PixelIdxList{1});
            otherwise,  nPixel = hist(Blocks(block).Igl(Blocks(block).Igl>0), 1:labels);            
        end    

        for p = 1:labels
            pixelIndex = CC.PixelIdxList{p}; % 50% faster than find(Igl==p)
            NumPeaks = sum(Blocks(block).peakMap(pixelIndex));

            if (nPixel(p) <= maxDotSize) && (nPixel(p) >= minDotSize)
                if NumPeaks == 0
                    peakValue = max(Blocks(block).Igm(pixelIndex));
                    peakIndex = find(Blocks(block).Igm(pixelIndex)==peakValue);
                    if numel(peakIndex) > 1
                        % limit one peak per label (where Igl==p)
                        peakIndex = peakIndex(round(numel(peakIndex)/2));
                    end
                    Blocks(block).peakMap(pixelIndex(peakIndex)) = 1;
                end
            else
                Blocks(block).Igl(pixelIndex) = 0;
            end
        end % for all labels
        
        % Add +1 to the threshold of all voxels that passed this iteration
        ValidVox = Blocks(block).Igl>0;
        Blocks(block).thresholdMap(ValidVox) = Blocks(block).thresholdMap(ValidVox)+1; 
    end % for all intensities

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
    if use_watershed
        wsTMapBin       = uint8(Blocks(block).thresholdMap>0);      % Binary map of thresholded voxels
        wsTMapBinOpen   = imdilate(wsTMapBin, ones(3,3,3));         % Dilate map with a 3x3x3 kernel (dilated perimeter acts like ridges between background and ROIs)
        wsTMapComp      = imcomplement(Blocks(block).thresholdMap); % Complement (invert) image. Required because watershed() separate holes, not mountains. imcomplement creates complement using the entire range of the class, so for uint8, 0 becomes 255 and 255 becomes 0, but for double 0 becomes 1 and 255 becomes -254.
        wsTMMod         = wsTMapComp.*wsTMapBinOpen;                % Force background outside of dilated region to 0, and leaves walls of 255 between puncta and background.
        wsTMLabels      = watershed(wsTMMod, connectedVoxN);        % Voxel connectivity watershed (faces), this will fill background with 1, ridges with 0 and puncta with 2,3,4,... in double format
        wsBkgLabel      = mode(double(wsTMLabels(:)));              % calculate background level
        wsTMLabels(wsTMLabels == wsBkgLabel) = 0;                   % seems that sometimes Background can get into puncta... so the next line was not good enough to remove all the background labels.
    else                          
        wsTMLabels = bwlabeln(Blocks(block).thresholdMap, connectedVoxN);   % Voxel connectivity without watershed on the original threshold map.
    end    
    
    wsLabelList                 = unique(wsTMLabels);
    Blocks(block).wsTMLabels    = uint16(wsTMLabels);
    Blocks(block).wsLabelList   = wsLabelList(2:end); % Remove background (1st label)
    Blocks(block).nLabels       = length(wsLabelList(2:end));
end

fprintf(['DONE in ' num2str(toc) ' seconds \n']);

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
        % Ensure watershed multi-peak objects are bigger then minDotSize
        if numel(VoxelsList{i}) >= minDotSize
            NumValidObjects = NumValidObjects+1;
        end
    end
end

if NumValidObjects == 0
    disp('No valid objects');
    Dots = [];
    return;
else
    tmpDots(NumValidObjects) = tmpDot; % Preallocate tmpDots
end

tmpDotNum = 0;
for block = 1:(NumBx*NumBy*NumBz)
    VoxelsList = label2idx(Blocks(block).wsTMLabels);    

    for i = 1:Blocks(block).nLabels
        Voxels = VoxelsList{i};
        
        % Accumulate only if object size is within minDotSize/maxDotSize        
        if numel(Voxels) >= minDotSize
            peakIndex = Voxels(Blocks(block).peakMap(Voxels)>0);
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

fprintf(['DONE in ' num2str(toc) ' seconds \n']);

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
    if isempty(tmpDots(i).Vol) || (tmpDots(i).Vol==0)
        continue;
    end
        
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

fprintf(['DONE in ' num2str(toc) ' seconds \n']);

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
fprintf(['DONE in ' num2str(toc) ' seconds \n']);

clear B* CC contour* cutOff debug Gm* i j k Ig* labels Losing* ans NumalidObjects
clear max* n* Num* Overlap* p peak* Possible* size(Post,2) size(Post,1) size(Post,3) Surrouding*
clear tmp* threshold* Total*  v Vox* Winning* ws* x* y* z* itMin DotsToDelete
clear block blockBuffer blockSize minDotSize minDotSize  MultiPeakDotSizeCorrectionFactor
clear ContendedVoxIDs idx Loser Winner minIntensity use_watershed ValidDots blockSearch
end
