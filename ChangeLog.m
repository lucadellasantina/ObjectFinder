%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2019 Luca Della Santina
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
% *Change log*
%
%  _*Version 5.17*              created on 2019-01-13 by Luca Della Santina_
%
%   + Inspect2D: improved accuracy in selecting objects with left-click
%   + Inspect2D: improved accuracy in moving zoom region with left-click
%
%  _*Version 5.16*              created on 2019-01-11 by Luca Della Santina_
%
%   + Inspect manually objects that are detected as NOT colocalized
%   + Simplified code for calling inspection of colocalized objects
%   + Uniformed font type across UI panels
%   + Fixed error if user aborts early inspection of colocalized objects
%
%  _*Version 5.15*              created on 2019-01-10 by Luca Della Santina_
%
%   + Iverted xy coordinates when importing SNT skeleton.traces files
%   + Fixed when checking colocalized objects with mask, mask was too dim
%   + Lamp shows busy yellow light when removing colocalization results
%   + Fixed error in pool of objects used for autocolocalization with mask
%
%  _*Version 5.14*              created on 2019-01-09 by Luca Della Santina_
%
%   + Fixed lstColoDone component was not updated when selecting new folder
%
%  _*Version 5.13*              created on 2018-10-09 by Luca Della Santina_
%
%   + Linear density along skeleton is also reported by depth
%   + Volume occupancy of objects is also reported within mask
%   + During image selection mask=0 always means no mask
%   + Fixed bug in automatic colocalization analysis with binary mask
%   + Fixed bug loading 2D images, when Z resolution was missing use XY res
%   + Fixed bug in labels of NN distribution plots and saved spreadsheets
%
%  _*Version 5.12*              created on 2018-10-08 by Luca Della Santina_
%
%   + Support for Imaris 7.2.4+, 8.x, 9.x
%   + Oblongness and major axis length exported as Imaris spots properties
%   + Backward compatibility with R2018a restored
%
%  _*Version 5.11*              created on 2018-10-07 by Luca Della Santina_
%
%   + Support for 2D images
%   + Fixed error when image files are missing voxel resolution info
%
%  _*Version 5.10*              created on 2018-10-04 by Luca Della Santina_
%
%   + Support for skeletons created with ImageJ's Simple Neurite Tracer
%   + Removed need for SkelFiner.mat
%
%  _*Version 5.9*              created on 2018-09-22 by Luca Della Santina_
%
%   + findObjects: Improved speed when found objects are > 1 million
%   + Added compatilibity with MATLAB R2018b
%   + Added tooltips for all major UI components
%
%  _*Version 5.8*              created on 2018-09-18 by Luca Della Santina_
%
%   + findObjects: Removed thresholdStep, now stepping is one by default
%   + About tab: added buttons to Homepage, User manual, Report issue
%   + Added tooltips to main UI components
%   + Upgraded project to MATLAB R2018b
%
%  _*Version 5.7*              created on 2018-09-17 by Luca Della Santina_
%
%   + findObjects: Improved speed of blocks conflict resolution by ~200X
%   + findObjects: No more need to delete empty objects after resolution
%
%  _*Version 5.6*              created on 2018-09-06 by Luca Della Santina_
%
%   + findObjects: Improved speed of objects accumulation by 10X
%   + findObjects: Improved speed of blocks conflict resolution by ~40X
%
%  _*Version 5.5*              created on 2018-09-06 by Luca Della Santina_
%
%   + findObjects: Improved speed of search algorithms by 10X
%   + Fixed error when loading multiple images of different size
%
%  _*Version 5.4*              created on 2018-09-06 by Luca Della Santina_
%
%   + Added Local thresholding mode, 30X faster than iterative thresholding
%   + User can choose between search algorithms
%   + Simplified object size to a single Max and Min diameter values
%   + Reverted resolution of duplicates to old method because recursive
%     intersect becomes too slow when more than 2000 objects are detected
%   + Cheched that objects are within size limits before watershed
%   + Different size images (not resolution) allowed in the same experiment
%   + New Copy objects button creates a new set of objects copy of selected
%   + FitShpere bug, now it can handle reference spheres of all sizes
%   + Fixed error in volume inspector if no shape properties are available
%   + Simplified fitSphere to calculate only Oblong and MajorAxisLength
%
%  _*Version 5.3*              created on 2018-09-06 by Luca Della Santina_
%
%   + Simplified resolution of duplicated objects across overlapping blocks
%   + Fixed insufficient block buffer calculation (now 2 times max xy size)
%   + Fixed inconsistent block size calculation (now 3 times max xy size)
%   + When detecting a new set of objects remember previous search settings
%
%  _*Version 5.2*              created on 2018-08-29 by Luca Della Santina_
%
%   + 8 new NeuralNetworks (VGG, SqueezeNet, GoogleNet, Inception, ResNet)
%   + Objects can be filtered based on Roundness and Major Axis Length
%   + Colocalized objects can now be saved as a new set of objects
%   % Colocalization with mask no longer asks for objects name
%   % Inspect2D: Fixed bug in applying secondary filter 
%   % Removed need for a custom readfunction when training NeuralNet
%   % Fixed selecting objects with names that are substrings of each other
%
%  _*Version 5.1*              created on 2018-08-28 by Luca Della Santina_
%
%   % Improved 5x the validation speed when using NeuralNetwork
%
%  _*Version 5.0*              created on 2018-08-22 by Luca Della Santina_
%
%   + Custom neural network can be trained and used as validation method
%   + Multiple objects per experiment are now allowed
%   + Nearest neighbor analysis with distance and overlap distribution calc
%   + Automatic colocalization analysis between nearest neigbor object sets
%   + User can disable block search
%   + Connectivity min. constrained to a certain # times the local noise
%   + New icons sea creature themed and updated graphical layout
%   + Oblongness is calculated/plotted as proxy for sphericity
%   + Inspect2D allows visualization of non-square images
%   + Inspect2D now able to show images smaller than the default 256x256
%   + Report plots distribution of size/brightness with custom fitting
%   + Conversion tool for data analyzed with version 4.x
%   + Lenght of major object axis is calculated as part of sphericity
%   % User can repeat sphericity calculation at will
%   % Ispect2D fixed wrong calculation of Pos and PosZoom
%   % Dots.mat now contains info on Settings/Density/NNdist/Coloc/Filter
%   % findObjects: Fixed wrong computation when watershed was disabled
%   % findObjects: Fixed skipping objects on border region
%   % findObjects: Fixed error when no LosingID is found
%   % Reorganized plot section into the broaded report setion
%   % Plots are in a new window by default and save always data as table
%   % Automatic colocalization analysis against mask 
%   % Removed need for files Density.mat, Coloc.mat, Filter.mat
%   % Fixes error if cancel is clicked when loading images
%   % fitSphere takes now into account XY resolution different from Z res.
%
% _*Version 4.10.5*            created on 2018-07-03 by Luca Della Santina_
%
%   + Colocalization of objects allowed with 2 channels at the same time
%   + Check double colocalization to reinspect only double-colocalized obj
%   + Inspect2D arrows and wasd allow nagivation across the left panel
%   + Colocalization settings panel on right hand of GUI
%   + Colocalization GUI panels visually separated by gray lines
%   % Colocalization GUI scrollbar overlapped with panel
%   % Sholl analysis plot didn't show axes when called after heatmap plot
%   % Colocalized channel replaces any previous version of it in Coloc.mat
%   - Removed settings.TPN from colocVideoFig (pwd filesep is default)
%   % Fixed bug preventing selection of border object in volume inspector
%   % Primary filter did not allow to lower threshold below starting value
%   % Renamed ITMax as Score in the GUI to allow new search algorithms
%   % Inverted order of presented panels in colocalization analysis
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