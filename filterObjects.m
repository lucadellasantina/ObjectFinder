%% Comments and Error log (EL****)

% 041409 aab changed line 332 'if gP.reset, gP = deFault;' to 'if gP.reset,
%   gP = default.gP;
% 042909 aab added readout for total puncta number and total passing puncta
%   number line 504-505.
% 081809 aab  added Imaris YesNo optional input to define Yes and No puncta
% 091009 had to turn off 'single' pass critereon (line 176)unique punctum
%   finder. It was interfering with Imaris Dot surface integrations. Need to
%   find what is wrong and fix.
% 092509 turned back on singles for normal test run
% 112009 -222 'added a filter for the TestCrit image so that noise in the
%   non arbor layers of Post is removed.' adam
% 1/14/2010 HO added the option to remove dots facing outside the mask or
% the image.
% 1/15/2010 HO added 3D tif saving for TestCrit and SGCrit, plus Blank 3D
% tiff file to provide a background for yes and no when you do it in Fiji.
% Also, added forceCorrect for this 3D yes and no tiff files.
% 1/20/2010 HO added the skipping option for the first pass if you already
% did it and came back with yes no tif.
% 6/25/2010 HO All the lines with Dots.cut was commented out because we
% don't do cut any more in anaMa.
% 7/9/2010 HO added 'if' loops in two places to skip loading Dend or DeltaF
% or DFOf if you don't have dendritic channel.
% 10/31/2010 Adam found a bug. I wrote 'if Settings.ImInfo.DendCh == 1' to
% enter enter/skip the 'if' loops that needs Dend channel, but DendCh is
% not always 1, so I changed them to 'if exist([TPN 'Dend.mat'])'.
% 1/4/2011 HO added 'if' loops before running EdgeDotCut, SingleZDotCut and
% PCA to skip them if you come back to re-do the analysis but not for all
% of them. (For example, just coming back to re-do PCA part.)
% 1/4/2011 HO modified the generation of TestCrit.tif to remove the
% background noise in Post channel by masking it with D.mat.
% 1/4/2011 HO added saving masked Post when YesNo3D was chosen so that yes
% no in 3D is easier if Post has lots of background.
% 1/29/2011 HO added forcing yes dots chosen in yes3Dforce.tif.
% 2/9/2011 HO removed Singles criterion because redundant voxels are
% now re-assigned to a signle dot at the end of dotfinder.
% 2/9/2011 HO moved the calculation of dP for all the dots inside if-end
% loop asking if PCA or MinThreshold will be run because there is no point
% of calculating it for every dot unless you use PCA or MinTreshold.
% 2/9/2011 HO removed the generation and the saving of Classify because
% most of them are duplicated in SG.
%
%AB 20101103 added simple definition of ratio to exclude dots outside
%dendrites
%
% 6/16/2011 HO added SGMinFieldOptions for choosing which criteria you want
% to use for minimum thresholding instead of setting non-chosen criteria to
% zero later because for some reason, some parameters (like deltaF) can be
% less than zero.
%
% 9/11/2011 HO added double z dot removing option. This is just like single
% z dot removing, and I found that double z dots are most likely noise as
% well. This works well especially when the image is noisier.
%
% 10/18/2011 Luca's xyStableDots to remove moving dots.

%%
function[SG] = filterObjects(Settings, SGOptions)

TPN = Settings.TPN;
if ~exist([TPN 'find'],'dir'), mkdir([TPN 'find']); end
if ~exist([TPN 'images'],'dir'), mkdir([TPN 'images']); end
if exist([TPN 'find' filesep 'SG.mat'],'file')
    load([TPN 'find' filesep 'SG.mat'])
else
    SG = [];
end
load([TPN 'Dots.mat'])


%% Do this analysis if never done before or if user wants to redo it
% but analysis is already done and user wants to grab only imaris passing
% objects, just call the function with only TPN as argument
if ~exist([TPN 'find' filesep 'SG.mat'], 'file')
    RedoFlag = 1;
elseif nargin < 2
    RedoFlag = 0;
else
    RedoFlag = input('First pass was already run. Do you want to rerun the first pass? Type 1 for rerunning, 0 for skipping to the smartGuide part.\n');
end

if RedoFlag
    % Get user input, define variable Defaults
    if  nargin < 2
        % Define default values for SGOptions
        SGOptions.EdgeDotCut = 1; %1 if you want to remove dots facing outside the mask or the image HO 1/14/2010
        SGOptions.SingleZDotCut = 1; %minimum number of voxels along z axis. Dots whose voxels are confined in a single z plane will be noise including speckling noise. This doesn't happen to PSD95 dots. HO 1/14/2010
        SGOptions.xyStableDots = 0; %1 if you want to remove moving dots Luca 10/18/2011
        SGOptions.PCA = 0; %1 if you want to select dots using PCA analysis
        SGOptions.MinThreshold = 0; %this is the conventional way that removes dots based on thresholds for each dot property defined in cP and dP HO 6/25/2010
        
        % Load SGOption values if stored from a previous analysis
        if isfield(SG,'SGOptions')  % Check if SGOptions has been created
            if length(fieldnames(SGOptions)) == length(fieldnames(SG.SGOptions))
                SGOptions = SG.SGOptions; % Load SGOptions
            end
        end
        
        % Ask user to choose
        tmpPrompt = {'Exclude dots on edge of the mask :',...
            'Exclude dots sitting on one Z plane :',...
            'Exclude moving dots along Z plane :',...
            'Perform PCA analysis clustering :',...
            'Specify manual threshold values :'};
        tmpAns = inputdlg(tmpPrompt, 'Select post-processing operations', 1,...
            {num2str(SGOptions.EdgeDotCut),...
            num2str(SGOptions.SingleZDotCut),...
            num2str(SGOptions.xyStableDots),...
            num2str(SGOptions.PCA),...
            num2str(SGOptions.MinThreshold)});
        
        % Store current choices
        SGOptions.EdgeDotCut    = str2double(tmpAns(1));
        SGOptions.SingleZDotCut = str2double(tmpAns(2));
        SGOptions.xyStableDots  = str2double(tmpAns(3));
        SGOptions.PCA           = str2double(tmpAns(4));
        SGOptions.MinThreshold  = str2double(tmpAns(5));
    end
    
    SG.SGOptions = SGOptions;
    save([TPN 'find' filesep 'SG.mat'],'SG')
    
    if (SGOptions.PCA == 1) || (SGOptions.MinThreshold == 1)
        % Collect dot properties
        clear dP
        dP.iTMax = double(Dots.ITMax); % Minimum times a dot must pass iterative threshold
        dP.iTSum = Dots.ItSum; % Minimum sum of volume of each threshold pass
        dP.vol = Dots.Vol;     % Minimum volume to pass
        dP.meanBright = double(Dots.MeanBright);
        dP.compact = Dots.Round.Compact; % Select for compact volumes
        dP.contrast=dP.iTMax./dP.meanBright;% Define Contrast as number of times passing threshold divided by mean brightness of puncta  or %max(1,(mB-(It*2)-gBG));
        dP.contrastVol=dP.iTMax./(dP.vol.^(1/3)); % Scale Contrast according to volume of puncta, or   %Contrast=It./max(mBG,1);
        for i = 1: Dots.Num
            brights = Dots.Vox(i).RawBright; % Use RawBright instead of repeatedly-median-filtered Igm generated in anaRa HO 6/8/2010
            brights = sort(brights);
            LB = length(brights);
            numBrights = fix(LB/10)+1;
            topB = brights(LB-numBrights:LB); %top 10% + 1 voxels counted as max brightness
            bottomB = brights(1:numBrights); %bottom 10% counted as min brightness
            dP.internalContrast(i) = (mean(topB)-mean(bottomB));
        end
        if find(Settings.ImInfo.DenCh) % in case you don't have dend channel, you can skip this part (DenCh will be 0). 7/9/2010 HO
            dP.ratio = Dots.Ratio;     % AB 20101103 added ratio for GRGM spots
            dP.deltaF = Dots.DF;       % Delta F (fluorecence - predicted fluorescence)
            dP.deltaFOf = Dots.DFOf;   % Delta F over F (predicted for red) for puncta
            dP.deltaFOfTop = Dots.DFOfTopHalf; % Minimum average delta F over f for the brightest %50 of voxels of a dot
        end
        
        SG.dotProperties = dP;
    end
    
    if SGOptions.PCA
        % Define default values for parameters choice
        SGPCAOptions.iTMax = 1;
        SGPCAOptions.iTSum = 1;
        SGPCAOptions.vol = 1;
        SGPCAOptions.meanBright = 1;
        SGPCAOptions.compact = 1;
        SGPCAOptions.contrast = 1;
        SGPCAOptions.contrastVol = 1;
        SGPCAOptions.internalContrast = 1;
        SGPCAOptions.deltaF = 0; % Delta F (fluorecence - predicted fluorescence)
        SGPCAOptions.deltaFOf = 0; % Delta F over F (predicted for red) for puncta
        SGPCAOptions.deltaFOfTop = 0; % Minimum average delta F over f for the brightest %50 of voxels of a dot
        
        % Load previously stored values id present
        if isfield(Settings,'SGPCAOptions')
            if length(fieldnames(SGPCAOptions)) == length(fieldnames(Settings.SGPCAOptions))
                SGPCAOptions = Settings.SGPCAOptions;
            end
        end
        
        % Ask user to choose parameters to computer for PCA analysis
        tmpPrompt = {'iTMax :',...
            'iTSum :',...
            'vol :',...
            'meanBright :',...
            'compact :',...
            'contrast',...
            'contrastVol',...
            'internalContrast',...
            'deltaF',...
            'deltaFof',...
            'deltaFofTop'};
        
        tmpAns = inputdlg(tmpPrompt, 'Parameters to use for PCA analysis (1:yes, 0:no)', 1,...
            {num2str(SGPCAOptions.iTMax),...
            num2str(SGPCAOptions.iTSum),...
            num2str(SGPCAOptions.vol),...
            num2str(SGPCAOptions.meanBright),...
            num2str(SGPCAOptions.compact),...
            num2str(SGPCAOptions.contrast),...
            num2str(SGPCAOptions.contrastVol),...
            num2str(SGPCAOptions.internalContrast),...
            num2str(SGPCAOptions.deltaF),...
            num2str(SGPCAOptions.deltaFOf),...
            num2str(SGPCAOptions.deltaFOfTop)});
        
        SGPCAOptions.iTMax            = str2double(tmpAns(1));
        SGPCAOptions.iTSum            = str2double(tmpAns(2));
        SGPCAOptions.vol              = str2double(tmpAns(3));
        SGPCAOptions.meanBright       = str2double(tmpAns(4));
        SGPCAOptions.compact          = str2double(tmpAns(5));
        SGPCAOptions.contrast         = str2double(tmpAns(6));
        SGPCAOptions.contrastVol      = str2double(tmpAns(7));
        SGPCAOptions.internalContrast = str2double(tmpAns(8));
        SGPCAOptions.deltaF           = str2double(tmpAns(9));
        SGPCAOptions.deltaFOf         = str2double(tmpAns(10));
        SGPCAOptions.deltaFOfTop      = str2double(tmpAns(11));
        
        SG.SGPCAOptions = SGPCAOptions;
        save([TPN 'find' filesep 'SG.mat'],'SG')
    end
    
    if SGOptions.MinThreshold
        SGMinThresholdOptions.iTMax = 0;
        SGMinThresholdOptions.iTSum = 0;
        SGMinThresholdOptions.vol = 0;
        SGMinThresholdOptions.meanBright = 0;
        SGMinThresholdOptions.compact = 0;
        SGMinThresholdOptions.contrast = 0;
        SGMinThresholdOptions.contrastVol = 0;
        SGMinThresholdOptions.internalContrast = 0;
        SGMinThresholdOptions.deltaF = 0; % Delta F (fluorecence - predicted fluorescence)
        SGMinThresholdOptions.deltaFOf = 0; % Delta F over F (predicted for red) for puncta
        SGMinThresholdOptions.deltaFOfTop = 0; % Minimum average delta F over f for the brightest %50 of voxels of a dot
        SGMinThresholdOptions.ratio = 1;
        
        if isfield(Settings,'SGMinThresholdOptions')  % Check if SGOptions has been created
            if length(fieldnames(SGMinThresholdOptions)) == length(fieldnames(Settings.SGMinThresholdOptions))
                SGMinThresholdOptions = Settings.SGMinThresholdOptions; % Load SGMinThresholdOptions
            end
        end
        
        tmpPrompt = {'iTMax :',...
            'iTSum :',...
            'vol :',...
            'meanBright :',...
            'compact :',...
            'contrast',...
            'contrastVol',...
            'internalContrast',...
            'deltaF',...
            'deltaFof',...
            'deltaFofTop',...
            'ratio'};
        
        tmpAns = inputdlg(tmpPrompt, 'Parameters to use for manual min threshold (1:yes, 0:no)', 1,...
            {num2str(SGMinThresholdOptions.iTMax),...
            num2str(SGMinThresholdOptions.iTSum),...
            num2str(SGMinThresholdOptions.vol),...
            num2str(SGMinThresholdOptions.meanBright),...
            num2str(SGMinThresholdOptions.compact),...
            num2str(SGMinThresholdOptions.contrast),...
            num2str(SGMinThresholdOptions.contrastVol),...
            num2str(SGMinThresholdOptions.internalContrast),...
            num2str(SGMinThresholdOptions.deltaF),...
            num2str(SGMinThresholdOptions.deltaFOf),...
            num2str(SGMinThresholdOptions.deltaFOfTop),...
            num2str(SGMinThresholdOptions.ratio)});
        
        SGMinThresholdOptions.iTMax            = str2double(tmpAns(1));
        SGMinThresholdOptions.iTSum            = str2double(tmpAns(2));
        SGMinThresholdOptions.vol              = str2double(tmpAns(3));
        SGMinThresholdOptions.meanBright       = str2double(tmpAns(4));
        SGMinThresholdOptions.compact          = str2double(tmpAns(5));
        SGMinThresholdOptions.contrast         = str2double(tmpAns(6));
        SGMinThresholdOptions.contrastVol      = str2double(tmpAns(7));
        SGMinThresholdOptions.internalContrast = str2double(tmpAns(8));
        SGMinThresholdOptions.deltaF           = str2double(tmpAns(9));
        SGMinThresholdOptions.deltaFOf         = str2double(tmpAns(10));
        SGMinThresholdOptions.deltaFOfTop      = str2double(tmpAns(11));
        SGMinThresholdOptions.ratio            = str2double(tmpAns(12));
        
        
        SG.SGMinThresholdOptions = SGMinThresholdOptions;
        save([TPN 'find' filesep 'SG.mat'],'SG')
        
        % Default dot criteria (first pass) Default values were inherited
        % from Josh's original program, and iTSum was found to be most useful.
        % Adam added ratio (ratio of dot channel over cell fill channel), which
        % is also useful in some cases. HO 6/16/2011
        cP.iTMax = 0; % Minimum times a dot must pass iterative threshold. This used to be 3.
        cP.iTSum = 50; % Minimum sum of volume of each threshold pass. This used to be 50.
        cP.vol = 0;  % Minimum volume to pass. This used to be 3.
        cP.meanBright = 0; % Minimum mean brightness of puncta. This used to be 0.
        cP.compact = 0; % select for compact volumes. This used to be commented out.
        cP.contrast = 0; % measure of dot contrast (iterative threshold passes/ mean brightness). This used to be 0.05.
        cP.contrastVol = 0;  % Threshold for (ITMax)./(Dots.Vol.^(1/3)); This used to be 1.
        cP.internalContrast = 0; %This used to be 0.
        %cP.dist2Dend = 0; %distance of dot peak to dend filament
        %cP.distToMask = 1; %distance of dot peak to dend mask
        cP.deltaF = 0; % Delta F (fluorecence - predicted fluorescence). This used to be 2.
        cP.deltaFOf = 0; % Delta F over F (predicted for red) for puncta. This used to be 0.3.
        cP.deltaFOfTop = 0; % Minimum average delta F over f for the brightest %50 of voxels of a dot. This used to be 0.3.
        cP.ratio = 0.3; %AB 20101103 added ratio for GRGM spots, HO 2/16/2011 ~0.3 worked well for one of my PSD95CFP image.
        cP.reset = 0; % Resets Criteria to defaults
        
        defaultP.cP=cP; %Record as defaults
        
        
        if isfield(SG,'FirstThresholds')  % Check if FirstThresholds has been created
            if length(fieldnames(cP)) == length(fieldnames(SG.FirstThresholds))
                cP = SG.FirstThresholds; % Load FirstThresholds
            end
        end
        
        tmpPrompt = {'iTMax :',...
            'iTSum :',...
            'vol :',...
            'meanBright :',...
            'compact :',...
            'contrast',...
            'contrastVol',...
            'internalContrast',...
            'deltaF',...
            'deltaFof',...
            'deltaFofTop',...
            'ratio',...
            'reset'};
        
        tmpAns = inputdlg(tmpPrompt, 'Manual thresholds (0:no threshold)', 1,...
            {num2str(cP.iTMax),...
            num2str(cP.iTSum),...
            num2str(cP.vol),...
            num2str(cP.meanBright),...
            num2str(cP.compact),...
            num2str(cP.contrast),...
            num2str(cP.contrastVol),...
            num2str(cP.internalContrast),...
            num2str(cP.deltaF),...
            num2str(cP.deltaFOf),...
            num2str(cP.deltaFOfTop),...
            num2str(cP.ratio),...
            num2str(cP.reset)});
        
        cP.iTMax            = str2double(tmpAns(1));
        cP.iTSum            = str2double(tmpAns(2));
        cP.vol              = str2double(tmpAns(3));
        cP.meanBright       = str2double(tmpAns(4));
        cP.compact          = str2double(tmpAns(5));
        cP.contrast         = str2double(tmpAns(6));
        cP.contrastVol      = str2double(tmpAns(7));
        cP.internalContrast = str2double(tmpAns(8));
        cP.deltaF           = str2double(tmpAns(9));
        cP.deltaFOf         = str2double(tmpAns(10));
        cP.deltaFOfTop      = str2double(tmpAns(11));
        cP.ratio            = str2double(tmpAns(12));
        cP.reset            = str2double(tmpAns(13));
        
        if cP.reset
            cP = defaultP.cP; % If reset pressed, reset values to defalut
        end
        
        SG.FirstThresholds = cP;
        save([TPN 'find' filesep 'SG.mat'],'SG')
    end
    
    
    %% Apply Exclusion Criteria to Puncta
    pass = ones(1,Dots.Num); %set up vector to record threshold passes
    
    % added the following if-end to remove dots facing outside the mask or image. 1/14/2010 HO
    if SGOptions.EdgeDotCut
        if exist([TPN 'data' filesep 'NonEdgeDots.mat'], 'file') %if-end loop added to remove the repetition 1/4/2011 HO
            EdgeDotCutRedoFlag = input('EdgeDotCut was already run. Do you want to rerun EdgeDotCut? Type 1 for rerunning, 0 for skipping.\n');
        else
            EdgeDotCutRedoFlag = 1;
        end
        
        if EdgeDotCutRedoFlag %if-end loop added to remove the repetition 1/4/2011 HO
            
            load([TPN 'Mask.mat']);
            Mask = uint8(Mask);
            Mask = bwperim(Mask, 6); %this operation will leave mask voxels facing 0 or outside the image as 1, and change the other mask voxels to 0.
            VoxIDMap = zeros(Dots.ImSize);
            for i=1:Dots.Num
                VoxIDMap(Dots.Vox(i).Ind)=i;
            end
            EdgeVoxIDMap = Mask.*VoxIDMap; %contour voxels located at the edge of the mask or image remains, and shows the dot ID#, other voxels are all 0.
            clear D;
            EdgeDotIDs = unique(EdgeVoxIDMap);
            if EdgeDotIDs(1) == 0
                EdgeDotIDs(1)=[];
            end
            NonEdgeDots = ones(1,Dots.Num);
            NonEdgeDots(1, EdgeDotIDs)=0;
            save([TPN 'data' filesep 'NonEdgeDots.mat'],'NonEdgeDots')
            pass = pass & NonEdgeDots; % Exclude edge dots
            
        else
            load([TPN 'data' filesep 'NonEdgeDots.mat']);
            pass = pass & NonEdgeDots; % Exclude edge dots
        end
    end
    
    %added the following line to exclude dots whose voxels spread only in one
    %z plane. This is not necessary for PSD95 dots but sometimes works well
    %with CtBP2 dots which include very dim noisy dots and speckling noise.
    %HO 1/14/2010
    if SGOptions.SingleZDotCut
        if exist([TPN 'data' filesep 'NonSingleZDots.mat'], 'file')
            NonSingleZDotCutRedoFlag = input('NonSingleZDotCut was already run. Do you want to rerun NonSingleZDotCut? Type 1 for rerunning, 0 for skipping.\n');
        else
            NonSingleZDotCutRedoFlag = 1;
        end
        
        if NonSingleZDotCutRedoFlag
            zVoxNum = zeros(1,Dots.Num);
            for i=1:Dots.Num
                zVoxNum(i) = length(unique(Dots.Vox(i).Pos(:,3)));
            end
            SingleZDotIDs = zVoxNum==1;
            NonSingleZDots = ones(1,Dots.Num);
            NonSingleZDots(1, SingleZDotIDs)=0;
            save([TPN 'data' filesep 'NonSingleZDots.mat'],'NonSingleZDots')
            pass = pass & NonSingleZDots; % Exclude single Z dots
            
        else
            load([TPN 'data' filesep 'NonSingleZDots.mat']);
            pass = pass & NonSingleZDots; % Exclude single Z dots
        end
    end
    
    % Remove Dots that are moving along Z stack
    if SGOptions.xyStableDots
        if exist([TPN 'data' filesep 'xyStableDots.mat'], 'file')
            xyStableDotsRedoFlag = input('XY Stable Dots already computed. Redo? 1 = YES, 0 = Use pre-calculated.\n');
        else
            xyStableDotsRedoFlag = 1;
        end
        
        if xyStableDotsRedoFlag
            xyStableDots = ones(1,Dots.Num);                                %Store Dots passing the test
            for i=1:Dots.Num
                zPlanes = sort(unique(Dots.Vox(i).Pos(:,3)));               % Find unique z planes and store value of their Z position
                xyPos = zeros(numel(zPlanes), 2);                           % Store here XY position of centroids for each Z plane
                
                for j=1:numel(zPlanes)                                      % For each z plane
                    zPosMask = Dots.Vox(i).Pos(:,3) == zPlanes(j);          % Find voxels belonging to the current Z plane
                    brightMask = Dots.Vox(i).RawBright == max(Dots.Vox(i).RawBright(zPosMask)); % Find brightest voxels
                    xyPos(j,:) = [mean(Dots.Vox(i).Pos(zPosMask & brightMask,1)),...
                        mean(Dots.Vox(i).Pos(zPosMask & brightMask,2))];    % Store position of centroid
                end
                %HO interpretation, removing dots that are moving either x or y direction
                %with its std more than a threshold number of voxels, here set to 2.
                %10/18/2011
                if (std(xyPos(:,1))>2) || (std(xyPos(:,2))>2)                % Test centroids are moving for more than 2 st.dev on XY plane
                    xyStableDots(i)=0;                                      % False if not aligned
                end
            end
            save([TPN 'data' filesep 'xyStableDots.mat'],'xyStableDots')
            pass = pass & xyStableDots;                                     % Trim moving dots away
        else
            load([TPN 'data' filesep 'xyStableDots.mat']);
            pass = pass & xyStableDots;                                     % Trim moving dots away
        end
        fprintf('Dots excluded because moving during aquisition: %u\n', numel(xyStableDots) - numel(find(xyStableDots)));
    end
    
    %PCA analysis HO 6/8/2010
    if SGOptions.PCA
        if exist([TPN 'data' filesep 'PCAPassDots.mat'],'file')
            PCARedoFlag = input('PCA was already run. Do you want to rerun PCA? Type 1 for rerunning, 0 for skipping.\n');
        else
            PCARedoFlag = 1;
        end
        
        if PCARedoFlag
            runFields = fieldnames(dP);
            dPMat=[];
            counter=0;
            for i = 1: length(runFields)
                if isfield(SGPCAOptions,runFields{i}) % check if there is the same field in SGPCAOptions for that property
                    if SGPCAOptions.(runFields{i}) == 1
                        counter = counter+1;
                        dPMat(counter,:) = dP.(runFields{i})(pass)/std(dP.(runFields{i})(pass));
                        disp([runFields{i}  '  will be used for PCA.' ]);
                    end
                end
            end
            dPMat = dPMat';
            
            [coef, zscore, pcvars] = princomp(dPMat);
            cumsum(pcvars./sum(pcvars) * 100); %check if two PCA components can account for >90% of variance, otherwise this analysis will not work good.
            coef; %check each criteria is used well
            cfigure(20,20);
            scatter(zscore(:,1),zscore(:,2),'k.');
            hold on
            scatter(zscore(dP.iTSum(pass)<100,1),zscore(dP.iTSum(pass)<100,2),'r.');
            scatter(zscore(dP.iTSum(pass)<50,1),zscore(dP.iTSum(pass)<50,2),'b.');
            scatter(zscore(dP.iTSum(pass)<20,1),zscore(dP.iTSum(pass)<20,2),'m.');
            legend('100<=iTSum', '50<=iTSum<100', '20<=iTSum<50', 'iTSum<20');
            
            disp('press enter after circling PASS dots with a polygon');
            [X,Y]=getline(gcf,'closed');
            plot(X,Y,'g');
            in=find(inpolygon(zscore(:,1),zscore(:,2),X,Y));
            scatter(zscore(in,1),zscore(in,2),'g');
            pause(3);
            clf
            
            TempPassDotNum = find(pass==1);
            PCAPassDotIDs = TempPassDotNum(in);
            PCAPassDots = zeros(1,Dots.Num);
            PCAPassDots(1, PCAPassDotIDs)=1;
            save([TPN 'data' filesep 'PCAPassDots.mat'],'PCAPassDots')
            pass = pass & PCAPassDots; % Include PCA Pass dots
            
        else
            load([TPN 'data' filesep 'PCAPassDots.mat']);
            pass = pass & PCAPassDots; % Include PCA Pass dots
        end
    end
    
    if SGOptions.MinThreshold
        runFields = fieldnames(dP);
        for i = 1: length(runFields)
            if isfield(cP,runFields{i}) % check if there is a threshold for that property
                pass = pass &  dP.(runFields{i})>=cP.(runFields{i}); %execute threhold
                disp([runFields{i} ' ' num2str(sum(pass))]);
            else
                disp(['no theshold for  ' runFields{i}]); %notify if no threshold exists
            end
        end
    end
    
    %Apply distances threshold
    %pass = pass & (Dots.DistToMask <= cP.distToMask); % apply minimum distance
    %pass = pass & (Dots.Dist2Dend <= cP.dist2Dend); % apply minimum distance to dend
    SG.pass1=pass';
    save([TPN 'find' filesep 'SG.mat'],'SG');
    
    P=find(pass); %% creat list of passing puncta
    
else %if RedoFlag is not 1
    load([TPN 'find' filesep 'SG.mat']);
    pass=SG.pass1;
    P=find(pass);
end


%% Draw image
% Create relevant image matricies
maxID=zeros(Dots.ImSize(1),Dots.ImSize(2),'uint16');
AllmaxID=zeros(Dots.ImSize(1),Dots.ImSize(2),'uint16');
maxPassed=zeros(Dots.ImSize(1),Dots.ImSize(2),'uint8');
YXsize=Dots.ImSize(1)*Dots.ImSize(2); %?
DisAmAll=maxPassed; % Plot all Dot Voxels
DisAm=maxPassed;    % Plot voxels from Dots that pass criteria

% Create pic of passed
for i =1:Dots.Num
    %index is assigned from the top z plane to the bottom z plane in order
    %so for example the first assigned voxel in the second plane has an
    %index of YXsize+1. Thus, mod(Dots.Vox(i).Ind-1,YXsize)+1 will bring all
    %the voxels in the dot to the same z plane
    DisAmAll(mod(Dots.Vox(i).Ind-1,YXsize)+1)=DisAmAll(mod(Dots.Vox(i).Ind-1,YXsize)+1)+1;
    AllmaxID(mod(Dots.Vox(i).Ind-1,YXsize)+1)=i; %This will overwrite voxels with the same x y, but different z? 1/5/2010 HO
end

for i = 1: length(P)
    maxID(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=P(i);
    maxPassed(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=200; % Assign number ( could be dot value)
    DisAm(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=DisAm(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)+1;  %Stack labels
end

% Assign different values for pixels corresponding to one vs more than one dot
OverLapped=DisAm;
OverLapped(DisAm==1)=150;
OverLapped(DisAm>1)=255;
%OverLapped at this point will be 150 in voxels where there was 1 passed dot voxel in
%that xy position throughout all z, 255 in the voxels where there were more
%than 1 passed dot voxels in that xy position throughout all z planes.

%load Raw
if exist([TPN 'images' filesep 'maxRaw.mat'],'file')
    load([TPN 'images' filesep 'maxRaw.mat'])
elseif exist([TPN 'images' filesep 'RawMax.tif'],'file')
    maxRaw=imread([TPN 'images' filesep 'RawMax.tif']);
    save([TPN 'images' filesep 'maxRaw.mat'],'maxRaw');
else
    load([TPN 'Post.mat'])
    imgCutUp = max(Dots.Pos(SG.pass1,3))+3; %Dots.Pos(SG.pass1,3) will be the z positions of all the passed dots
    imgCutDown =  min(Dots.Pos(SG.pass1,3))-3;
    if imgCutDown < 1            % border gaurds
        imgCutDown = 1;          % bg
    end
    if imgCutUp > size(Post,3)   % bg
        imgCutUp = size(Post,3); % bg
    end
    
    %Mask the PostCut because imgCutUP doesn't help if the retina is oblique 1/4/2011
    load([TPN 'Mask.mat']);
    PostCut = Post.*Mask;
    
    PostCut(:,:,imgCutUp:end) = 0; % need to get rid of the noise in the cell body layers in the Post channel
    
    if exist([TPN 'Dend.mat'],'file') %in case you don't have Dend channel 7/9/2010 HO
        load([TPN 'Dend.mat'])
        maxRaw=max(Dend,[],3);
    end
    maxRaw(:,:,2)=max(PostCut,[],3); %if Dend doesn't exist, this will pad 0 in the first z plane. 7/9/2010 HO
    save([TPN 'images' filesep 'maxRaw.mat'],'maxRaw')
end

% combine and save and image Comparison
TestID=uint16(maxRaw)*2^8;
TestCrit=maxRaw;
TestID(:,:,3)=maxID;
TestCrit(:,:,3)=OverLapped;
imwrite(TestCrit,[TPN 'find' filesep 'TestCrit.tif'],'Compression','none')
imwrite(TestID,[TPN 'images' filesep 'TestID.tif'],'Compression','none')
subplot(1,2,1),image(TestCrit),pause(.01)

%% Use user labeled images to Identify good and bad dots

Miss=[]; %Define vector to list artifacts
Hit = []; %define vector to list identified puncta
%If no hits are defined, define everything that is not a miss as a hit
if isempty(Hit)
    Hit = unique(AllmaxID);
    Hit = setdiff(Hit,Miss);
    Hit = Hit(Hit>0);
end
SG.manual.Miss=Miss;
SG.manual.Hit=Hit;

%% Pick best Thresholds

clear gP
gP.stepThresholds = 5;
gP.repSearch = 5;
gP.forceCorrect = 1;  % Force user input to be correct
gP.reset = 0;


gP.iTMax = 0;
gP.iTSum = 0;
gP.vol = 0;
gP.meanBright = 0;
gP.contrast = 0;
gP.contrastVol = 0;
gP.internalContrast = 0;
gP.deltaF = 0;
gP.deltaFOf = 0;
gP.deltaScale = 0;
gP.deltaFOfTop = 0;
gP.deltaCon = 0;

default.gP = gP; %Remember defaults

if isfield(SG,'guideThresholds')  % Check if FirstThresholds has been created
    if length(fieldnames(gP)) == length(fieldnames(SG.guideThresholds))
        gP = SG.guideThresholds; % Load FirstThresholds
    end
end

pass2 = pass;  % Collect dots with tighter thresholds

%run final pass adding manual Hits and Misses
passF=pass2;
if gP.forceCorrect
    if exist([TPN 'find' filesep 'yes.tif'], 'file')|| exist([TPN 'find' filesep 'YesNo.mat'],'file')
        passF(Hit)=1;
    end
    passF(Miss)=0;
end
SG.pass2=pass2';
SG.passF=passF';

save([TPN 'find' filesep 'SG.mat'],'SG')

P=find(passF); % list of passing puncta


%% Draw image
totalPassing = length(pass2);
disp(['Total number of initially detected objects: ' num2str(totalPassing)]);
totalPassWithManual = length(P);        %042909 aab added readout for total passing puncta
disp(['Total number of objects validated after post-processing: ' num2str(totalPassWithManual)]);

maxSum=zeros(Dots.ImSize(1),Dots.ImSize(2));
maxID1=maxSum; maxID2 = maxSum; maxID3 = maxSum;


for i = 1: length(P)
    maxID1(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=rand*100+50; %rand outputs a random number between 0 and 1, so this line will produce a random number between 50 and 150 at the voxel positions of a passed dot
    maxID2(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=rand*100+50;
    maxID3(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=rand*100+50;
    maxSum(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=maxSum(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)+1; %Isn't this the same as DisAm???
end

%OverLapped will show 60 in the voxels where there was 1 passed dot voxel in
%that xy position throughout all z, 100 in the voxels where there were more
%than 1 passed dot voxels in that xy position throughout all z planes, then
%add 150 more for all of these voxels. Why doing this way?
OverLapped=maxSum*0;
OverLapped(DisAm>0)=60;
OverLapped(DisAm>1)=100;
OverLapped(maxSum>0)=OverLapped(maxSum>0)+150;

MaxC=maxID1+(maxSum>1)*1000;
MaxC(:,:,2)=maxID2+(maxSum>1)*1000;
MaxC(:,:,3)=maxID3+(maxSum>1)*1000;
MaxC=uint8(MaxC);
subplot(1,2,2),image(MaxC),pause(.01)
% image(max(fullID,[],3)),P(i),pause

%combine and save and image Comparison
SGCrit=maxRaw;
SGCrit(:,:,1)=SGCrit(:,:,1);
SGCrit(:,:,2)=SGCrit(:,:,2);
SGCrit(:,:,3)=OverLapped;
imwrite(SGCrit,[TPN 'find' filesep 'SGCrit.tif'],'Compression','none')
imwrite(MaxC,[TPN 'find' filesep 'MaxCids.tif'],'Compression','none')

%image(SGCrit), pause(.01)

%% Draw image from passI (if Imaris selection of valid/invalid object was exported back to matlab)
if isfield(SG,'passI')
    P=find(SG.passI); %% list of passing puncta
    
    maxSum=zeros(Dots.ImSize(1),Dots.ImSize(2));
    maxID1=maxSum; maxID2 = maxSum; maxID3 = maxSum;
    
    for i = 1: length(P)
        maxID1(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=rand*100+50; % Rand outputs a random number between 0 and 1, so this line will produce a random number between 50 and 150 at the voxel positions of a passed dot
        maxID2(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=rand*100+50;
        maxID3(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=rand*100+50;
        maxSum(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)=maxSum(mod(Dots.Vox(P(i)).Ind-1,YXsize)+1)+1; %Isn't this the same as DisAm???
    end
    
    %OverLapped will show 60 in the voxels where there was 1 passed dot voxel in
    %that xy position throughout all z, 100 in the voxels where there were more
    %than 1 passed dot voxels in that xy position throughout all z planes, then
    %add 150 more for all of these voxels. Why doing this way?
    OverLapped=maxSum*0;
    OverLapped(DisAm>0)=60;
    OverLapped(DisAm>1)=100;
    OverLapped(maxSum>0)=OverLapped(maxSum>0)+150;
    
    MaxC=maxID1+(maxSum>1)*1000;
    MaxC(:,:,2)=maxID2+(maxSum>1)*1000;
    MaxC(:,:,3)=maxID3+(maxSum>1)*1000;
    MaxC=uint8(MaxC);
    figure('Name','Valid object after Imaris selection');
    image(MaxC);
    % image(max(fullID,[],3)),P(i),pause
    
    %combine and save and image Comparison
    ImarCrit=maxRaw;
    ImarCrit(:,:,1)=ImarCrit(:,:,1);
    ImarCrit(:,:,2)=ImarCrit(:,:,2);
    ImarCrit(:,:,3)=OverLapped;
    imwrite(ImarCrit,[TPN 'find' filesep 'ImarCrit.tif'],'Compression','none')
    imwrite(MaxC,[TPN 'find' filesep 'ImarMaxCids.tif'],'Compression','none')
    
    totalPassWithImaris = length(P);
    disp(['Total number of objects validated after Imaris selection: ' num2str(totalPassWithImaris)]);
end
end


