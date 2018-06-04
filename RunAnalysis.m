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

% Preliminary check of valid current working directory structure
if ~isdir([pwd filesep 'I'])
    error(['This folder is not valid for ObjectFinder analysis, '...
           'please change current working directory to one containing '...
           'images to analyze within an "I" subfolder']);
end

% Get the current working folder as base directory for the analysis
disp('---- ObjectFinder 4.9 analysis ----');
if exist([pwd filesep 'Settings.mat'], 'file'), load([pwd filesep 'Settings.mat']); end
Settings.TPN = [pwd filesep];
save([Settings.TPN 'Settings.mat'], 'Settings');
if ~isdir([Settings.TPN 'data']), mkdir([Settings.TPN 'data']); end
if ~isdir([Settings.TPN 'images']), mkdir([Settings.TPN 'images']); end

% Read images to be used for analysis
tmpDir=[Settings.TPN 'I' filesep];
tmpFiles=dir([tmpDir '*.tif']);

% Get dimensions of the first 3D TIF image (all other imagest must be same)
tmpImInfo = imfinfo([tmpDir tmpFiles(1).name]);
zs = numel(tmpImInfo); xs = tmpImInfo.Width; ys = tmpImInfo.Height;

% Retrieve XY and Z resolution from TIFF image descriptor
tmpXYres = num2str(1/tmpImInfo(1).XResolution);
tmpZres = '0.3';% Default Z resolution if not specified in the TIF image
if contains(tmpImInfo(1).ImageDescription, 'spacing=')
    tmpPos = strfind(tmpImInfo(1).ImageDescription,'spacing=');
    tmpZres = tmpImInfo(1).ImageDescription(tmpPos+8:end);
    tmpZres = regexp(tmpZres,'\n','split');
    tmpZres = tmpZres{1};
end

% Read all TIF images into a single Iraw matrix (X,Y,Z,Imge#)
Iraw=zeros(ys, xs, zs, numel(tmpFiles), 'uint8');
txtBar('Loading image stacks... ');
for i = 1:numel(tmpFiles)
    for j = 1:zs
        Iraw(:,:,j,i)=imread([tmpDir tmpFiles(i).name], j);
        txtBar( 100*(j+i*zs-zs)/(zs*numel(tmpFiles)) );
    end
end
txtBar('DONE');

Imax=squeeze(max(Iraw,[],3)); % Create a MIP of each image to display
figure('units', 'normalized', 'position', [0.05 0.25 0.9 0.4]);
for i = 1:size(Imax,3)
    subplot(1,size(Imax,3),i)
    image(Imax(:,:,i)*(500/double(max(max(Imax(:,:,i))))))
    title(['# ' num2str(i) ': ' tmpFiles(i).name]);
    set(gca,'box','off', 'YTickLabel',[],'XTickLabel',[]);
end
colormap gray(256);

% Ask user for image idendity settings
tmpPrompt = {'Objects image #:',...
             'Mask channel (0:no/use Mask.mat):',...
             'Neurites image # (0 = none):',...
             'xy resolution :',...
             'z resolution :',...
             'Debug mode (0:no, 1:yes):'};
tmpAns = inputdlg(tmpPrompt, 'Assign channels', 1,...
            {'3', '0', '1',tmpXYres,tmpZres,'0'});

Settings.ImInfo.xNumVox = xs;
Settings.ImInfo.yNumVox = ys;
Settings.ImInfo.zNumVox = zs;
Settings.ImInfo.PostCh  = str2double(tmpAns(1));
Settings.ImInfo.MaskCh  = str2double(tmpAns(2));
Settings.ImInfo.DenCh   = str2double(tmpAns(3));
Settings.ImInfo.xyum    = str2double(tmpAns(4));
Settings.ImInfo.zum     = str2double(tmpAns(5));
Settings.debug          = str2double(tmpAns(6));
save([Settings.TPN 'Settings.mat'], 'Settings');

% Write Channels into matlab files
if Settings.ImInfo.DenCh
    Dend = Iraw(:,:,:,Settings.ImInfo.DenCh);
    save([Settings.TPN 'Dend.mat'],'Dend');
end

if Settings.ImInfo.PostCh
    Post=Iraw(:,:,:,Settings.ImInfo.PostCh);
    save([Settings.TPN 'Post.mat'],'Post');
end

if Settings.ImInfo.MaskCh
    Mask = Iraw(:,:,:,Settings.ImInfo.MaskCh);
    Mask = Mask / max(max(max(Mask))); % Normalize mask max value to 1
    save([Settings.TPN 'Mask.mat'],'Mask');
    saveastiff(Post, [Settings.TPN 'images' filesep 'PostMask.tif']); %save 3-D tiff image of the masked Post
elseif exist([Settings.TPN 'Mask.mat'], 'file')
    disp('Loading Mask from Mask.mat');
    load([Settings.TPN 'Mask.mat']);
else
    % Create dummy mask with all ones to process the entire image
    Mask = ones(size(Post), 'uint8');
    save([Settings.TPN 'Mask.mat'],'Mask');
end
close all; clear i j Iraw Imax Is tmp* xs ys zs ans;

tmpPrompt = {'x-y diameter of the biggest dot (um, default 1)',...
             'z diameter of the biggest dot (um, default 2)',...
             'x-y diameter of the smallest dot (um, default 0.25)',...
             'z diameter of the smallest dot (um, normally 0.5)',...
             'Intensity thresholds stepping (default 2)',...
             'Minimum iteration threshold (default 2)',...
             'Split multi-peak objects using watershed?(1:yes, 0:no)'};
tmpAns = inputdlg(tmpPrompt, 'ObjectFinder settings', 1,...
           {'1','2','0.25','0.5','2','2','1'});

% Calculate volume of the minimum / maximum dot sizes allowed
% largest CtBP2 = elipsoid 1um-xy/2um-z diameter = ~330 voxels (.103x.103x0.3 um pixel size)
MaxDotSize = round((4/3*pi*(str2double(tmpAns(1))/2)*(str2double(tmpAns(1))/2)*(str2double(tmpAns(2))/2)) / (Settings.ImInfo.xyum*Settings.ImInfo.xyum*Settings.ImInfo.zum));
MinDotSize = round((4/3*pi*(str2double(tmpAns(3))/2)*(str2double(tmpAns(3))/2)*(str2double(tmpAns(4))/2)) / (Settings.ImInfo.xyum*Settings.ImInfo.xyum*Settings.ImInfo.zum));

Settings.objfinder.blockBuffer= round(str2double(tmpAns(1))/Settings.ImInfo.xyum);  % Overlapping buffer region between search block should be as big as the biggest dot we want to measure to make sure we are not missing any.
Settings.objfinder.blockSize = max(64, 4*Settings.objfinder.blockBuffer); % Use 3x blockBuffer for maximum speed or 64, whichever bigger (64 works well for computers with 16Gb RAM)
Settings.objfinder.thresholdStep = str2double(tmpAns(5)); % stepping when iteratively looping through pixel intensities for connected components
Settings.objfinder.maxDotSize = MaxDotSize;       % max dot size exclusion criteria for single-peak dot DURING ITERATIVE THRESHOLDING, NOT FINAL.
Settings.objfinder.minDotSize= MinDotSize;        % min dot size exclusion criteria DURING ITERATIVE THRESHOLDING, NOT FINAL.
Settings.objfinder.itMin = str2double(tmpAns(6)); % added by HO 2/9/2011 minimum iterative threshold allowed to be analyzed as voxels belonging to any dot...filter to remove value '1' pass thresholds. value '2' is also mostly noise for PSD95 dots, so 3 is the good starting point HO 2/9/2011
Settings.objfinder.minFinalDotITMax = 3;          % minimum ITMax allowed as FINAL dots. Any found dot whose ITMax is below this threshold value is removed from the registration into Dots. 5 will be the best for PSD95. HO 1/5/2010
Settings.objfinder.watershed = str2double(tmpAns(7));

save([Settings.TPN 'Settings.mat'], 'Settings');
clear BlockBuffer MaxDotSize MinDotSize tmp* h

%% --- Find objects and calculate their properties ---
% Seach objects inside the masked volume
Dots = findObjects(Post.*Mask, Settings);
save([Settings.TPN 'Dots.mat'],'Dots');

%% Create fields about sphericity of objects (Rounding)
Dots = fitSphere(Dots, Settings);
save([Settings.TPN 'Dots.mat'],'Dots');

%% Filter objects according to the following post-processing criteria (SG)
tmpOptions.EdgeDotCut = 0;    % remove dots on edge of the expanded mask
tmpOptions.SingleZDotCut = 1; % remove dots sitting on only one Z plane
tmpOptions.xyStableDots = 0;  % remove objs whose centroid is not Z-stable
tmpOptions.Thresholds.ITMax = 0;        % custom thresholds disabled
tmpOptions.Thresholds.Vol = 0;          % custom thresholds disabled
tmpOptions.Thresholds.MeanBright = 0;   % custom thresholds disabled
Filter = filterObjects(Settings, Dots, tmpOptions);
save([Settings.TPN 'Filter.mat'],'Filter');
clear tmpOptions

%% Volume inspector with threshold selection
inspectVolume2D(Post.*Mask, Dots, Filter);
load([Settings.TPN 'Filter.mat']); % reload filter with updated thresholds

%% In Imaris select ItMax as filter, and export objects back to matlab.
exportObjectsToImaris(Settings, Dots, Filter); % Transfer objects to Imaris

%% If a skeleton is present then calculate properties of the individual cell
load([Settings.TPN 'Settings.mat']);
load([Settings.TPN 'Filter.mat']); % Reload to synch imaris-selectied
if exist([Settings.TPN 'Skel.mat'], 'file')
    load([Settings.TPN 'Skel.mat'])
    load([Settings.TPN 'Settings.mat'])
    Skel = calcSkelPathLength(Skel, Settings.debug);
    save([Settings.TPN 'Skel.mat'],'Skel')
    Skel = generateFinerSkel(Skel, Settings.ImInfo.xyum, Settings.debug);
    Skel = calcSkelPathLength(Skel, Settings.debug);
    save([Settings.TPN 'SkelFiner.mat'], 'Skel');

    Dots = distDotsToCellBody(Dots, Skel, Settings);
    Dots = distDotsToSkel(Dots, Skel, Settings);
    save([Settings.TPN 'Dots.mat'],'Dots');

    Density = calcDensity(Settings, getFilteredObjects(Dots, Filter), Skel, true); % Generate heatmaps of object density
    calcPathLengthStats(Settings, getFilteredObjects(Dots, Filter), Skel, true); % Plot distribution along dendrites
else
    % Compute and plot object distribution as function of volume depth
    Density = calcDotDensityAlongZ(Settings, getFilteredObjects(Dots, Filter), true);
end
    save([Settings.TPN 'Density'], 'Density') %fixed to save only Settings (9/2/09 HO)

disp('---- ObjectFinder analysis done! ----');

%% Change log
%
% _*Version 4.10*             created on 2018-06-03 by Luca Della Santina_
%
%   + Colocalization of objects allowed with 2 channels at the same time
%   + Inspect2D arrows and wasd allow nagivation across the left panel
%   + Colocalization settings panel on right hand of GUI
%   + Colocalization GUI panels visually separated by gray lines
%   % Colocalization GUI scrollbar overlapped with panel
%   % Sholl analysis plot didn't show axes when called after heatmap plot
%   - Removed settings.TPN from colocVideoFig (pwd filesep is default)
%
% _*Version 4.9.1*             created on 2018-05-25 by Luca Della Santina_
%
%   + Inspect2D allows to select individual objects in the zoomed region
%   + Inspect2D allows to toggle validation status of selected object
%   + Inspect2D right-clicking zoomed region panel centers the view there
%   % Inspect2D left-clicking obhect highlights it in blue
%   % Filter now saves Threshold field among options on file
%   % Filter now loads threshold direction from options on file
%   % Filter now defaults to average values for if no value is on file
%   % Total # of valid objects updates when user manually change validation

% _*Version 4.8*               created on 2018-05-20 by Luca Della Santina_
%
%   + Bigger button sizes (better for HiDPI screens)
%   + Inspector type selection (Stack inspector vs Imaris 7)
%   + 2D inspector allows switching show objects via checkbox (or spacebar)
%   + 2D inspector allows filtering direction >= or <= than set threshold
%   % Update folder path in saved Settings.mat upon home folder selection
%   % try statement catches errors pushing custom statistics to imaris
%   % Removed need for Settings.TPN, just use current working directory
%   % New GUI required MATLAB R2018a
%   % 2D inspector saves filter thresholds chosen by user into Filter.mat
%   - 2D inspector cliking on zoomed region does not blank out zoomed view
%
% _*Version 4.7*               created on 2018-03-31 by Luca Della Santina_
%
%  + Colocalization analysis tab: manual colocalization
%  + Colocalization of multiple channels are accumulated into Coloc.mat
%  % Colocalization shows isolated object overlayed to Coloc. channel
%  % Fixed titles of colocalization and indpector windows
%  % Objects filtered using the 2D inspector are correctly passed to Imaris
%  % 2D Inspector allows "None" as primary threshold to show no highlights
%
% _*Version 4.6*               created on 2018-03-26 by Luca Della Santina_
%
%  % Reduced findObjects mem usage by passing only block volume to workers 
%  % Improved speed by 30% by optimizing search block size
%  % findObjects uses Dots struct array for simpler manipulations
%  % fixed missing Settings.mat when using RunAnalysis on new folder
%  - Removed minFinalDotSize from parameters, just use MinDotSize
%  - Removed multiPeakCorrectionfactor from parameters, use MaxDotSize
%  - Removed psychophisics cutoff values from findObjects
%
% _*Version 4.5*               created on 2018-03-13 by Luca Della Santina_
%
%  + Batch processing mode under the new Automate tab
%  % filterObjects accepts custom thresholds for ITMax, Vol, MeanBright
%
% _*Version 4.4*               created on 2018-03-10 by Luca Della Santina_
%
%  + Custom timer allows to start ObjectFinder at a specific time of day
%  + 2D inspector allows to pick a visual threshold with volume navigation
%  % Inspect3D returns error if Imaris cannot be started via COM interface
%  % Inspect3D optional whether to display validated and rejected objects
%  % Post, Dend and Mask are loaded at startup if present in working folder
%  % Fixed error in calculating object density by depth percentage
%
% _*Version 4.3*               created on 2018-03-01 by Luca Della Santina_
%
%  % Calculation of sphericity properties is now optional
%  % Inspect3D catches validated spots from imaris (no need for XTension)
%
% _*Version 4.2*               created on 2018-02-25 by Luca Della Santina_
%
%  + Added user control over search algorithm settings via GUI
%  + Added user control over filter settings via GUI
%  + Watershed segmentation is now optional in findObjects()
%  + Replaced princomp with pca for PCA analysis in fitShphere()
%
% _*Version 4.1*               created on 2018-02-24 by Luca Della Santina_
%
%  + Plot Sholl analysis on Skel
%  + getFilteredObjects returns all validated objects according to Filter
%  + Added License text in the GUI's About tab
%  + Added visual log on GUI during detection phase
%  - Removed need for grouped.mat, all Objects are store in Dots.mat
%
% _*Version 4.0*               created on 2018-02-08 by Luca Della Santina_
%
%  + Packaged ObjectFinder into a matlab app (requires MATLAB R2016b+)
%  + Added GUI using app designer (requires MATLAB R2016b+)
%  + Sholl analysis calculation for Skeleton
%  + GUI allows to save plot data as Excel table in "results" folder
%  + GUI allows to plot skeleton+objects in vector format for publication
%  + GUI allows plotting Density (linear or by depth) of objects
%  + GUI allows plotting in a separate window so plots can be saved
%  + GUI allows plotting heatmap if linear density alog skeleton
%  + additional scripts to plot objects density and size across experiments
%  % Do not ask which skel to select if only one is available in Imaris
%  % if SG.PassI does not exists, load SG.PassF by default in imaris
%  % Don't ask where to save skel/dots/mask when exporting from Imaris
%  % Pruned filterObjects from all suprefluous code
%  % Moved SG.mat to the main folder, now called Filter.mat
%  % Filter.PassF contains flags of most recent passing opjects
%  - removed dependency from dist.m and cfigure.m
%  - removed distinction between PassF and PassI, now last passing is PassF
%  - removed "find" folder
%  - removed "temp" folder
%  - removed on-screen plots from groupFacingObjects and filterObjects
%
% _*Version 3.0*               created on 2017-11-03 by Luca Della Santina_
%
%  + Multi-threaded findObjects (times faster = number of cores available)
%  + Complete multi-platform support (Windows / macOS / Linux)
%  + Z resolution is automatically detected from TIFF image description
%  - Removed median filtering of source images (unuseful to most people)
%  - Removed experiment detail description (unuseful to most people)
%  % All settings are stored in Settings.mat (no more TPN and similar file)
%  % Throw error if current working directory strucrue is invalid
%
% _*Version 2.5*               created on 2017-10-22 by Luca Della Santina_
%
%  + Display more than 4 images if present in the I folder
%  + Automatically read x-y image resolution from tif files saved by ImageJ
%  + Added text progress bars to follow progress during processing steps
%  + Added debug=0/1 mode in subroutines to toggle text/graphic output
%  - Removed dependency from getVars() to get user input
%  - Removed redundances in user inputs (i.e. image resolution asked twice)
%  - Removed anaRa, anaRead, CAsampleCollect, StratNoCBmedian, Gradient
%  - Merged redundant scripts(anaCB/anaCBGrouped, anaRd/anaRdGrouped)
%  % Unified Imaris XTensions under ObjectFinder_ names
%  % Imaris extensions provided visual confirmation dialog upon success
%  % Restructured main look into 4 distinct operations for maintainability
%  % Return Dots from objFinder and others instead of saving on disk
%  % Replaced GetMyDir dependency with pwd and work from current folder
%  % filterObjects(TPN) skips questions and just reprocess Imaris dots
%  % Stored ImageInfo (size,res) inside Grouped.InInfo for plotting
%
% _*TODO*_
%
%  Allow processing of 12/16-bit images
%  Make heatmaps plots with finer convolution disk (too coarse right now)
%  Resolve minDotsize vs minFnalDotSize (current minDotSize fixed at 3px)
%  Implement stepping=1 through gmode instead (current stepping of 2)