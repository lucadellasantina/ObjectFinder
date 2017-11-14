%% Colocalization - Manual analysis
%
% *This scripts allows to analyze whether each object found by ObjectFinder
% is co-localized to another signal of interest (loaded as image stack)
% The user is asked to review each object and judge whether is co-localized
% or non-colocalized to the signal of interest*
%
% Originally written for the colocalization of postsynaptic PSD95 puncta
% and presynaptic CtBP2 puncta.
%
% depends on: colocDotStackCutter.m  colocVideoFig.m
% -------------------------------------------------------------------------
% Version 1.3                                2017-11-02 Luca Della Santina
%
% + Automatic recognition of colocalizing channel name from .tif FileName

% Version 1.2                                2017-10-15 Luca Della Santina
%
% % Fixed problem saving Colo.mat as file was too big (use -v7.3 save flag)
%
% Version 1.1                                2017-08-11 Luca Della Santina
%
% - Removed dependency from other support script
% - Removed dependency from a saved working directory TPN (use pwd instead)
%
% Version 1.0                                      2015 Haruhisa Okawa
% -------------------------------------------------------------------------

TPN = [pwd filesep]; % Instead reading TPN file, get current working folder
load([TPN 'Settings.mat']);
load([TPN 'Grouped.mat']); %load the source dot to search for fish
load([TPN 'Post.mat']);

if exist([TPN 'Colo.mat'],'file')
    load([TPN 'Colo.mat']);
else
    [FileName, PathName] = uigetfile('*.tif');
    ImInfo = imfinfo([PathName FileName]);
    Colo = zeros(ImInfo(1).Height, ImInfo(1).Width, length(ImInfo));
    for j = 1:length(ImInfo)
       Colo(:,:,j)=imread([PathName FileName], j);
    end
    save([TPN 'Colo.mat'],'Colo', '-v7.3');
end

if exist([TPN 'ColocManual.mat'],'file')
    load([TPN 'ColocManual.mat'])
else
    [~, fName, ~] = fileparts(FileName);
    tmpPrompt = {'Reference objects: ', 'Colocalized signal:'};
    tmpAns = inputdlg(tmpPrompt, 'Assign channels', 1, {'PSD95', fName});
    ColocManual.Source = tmpAns(1);
    ColocManual.Fish1 = tmpAns(1);

    ManualColocAnalyzingFlag = ones([1,Grouped.Num], 'uint8');
    ColocManual.ListDotIDsManuallyColocAnalyzed = find(ManualColocAnalyzingFlag == 1);
    ColocManual.TotalNumDotsManuallyColocAnalyzed = length(ColocManual.ListDotIDsManuallyColocAnalyzed);
    ColocManual.ColocFlag = zeros([1,ColocManual.TotalNumDotsManuallyColocAnalyzed], 'uint8');
end

PostVoxMap = zeros(size(Post), 'uint8');
DotRepeatFlag=0;
PostReScalingFactor=1;
ColoReScalingFactor=1;
while ~isempty(find(ColocManual.ColocFlag == 0, 1))
    if DotRepeatFlag == 0
        RemainingDotIDs = ColocManual.ListDotIDsManuallyColocAnalyzed(ColocManual.ColocFlag == 0);
        NumRemainingDots = length(RemainingDotIDs);
        dot = ceil(rand*NumRemainingDots); % randomize the order of analyzing dots
        DotNum = RemainingDotIDs(dot);
        PostVoxMap(Grouped.Vox(DotNum).Ind) = 150;
        CutNumVox = [60, 60, 20];
        PostCut = colocDotStackCutter(Post, Grouped, DotNum, [], CutNumVox);
        ColoCut = colocDotStackCutter(Colo, Grouped, DotNum, [], CutNumVox);
        PostVoxMapCut = colocDotStackCutter(PostVoxMap, Grouped, DotNum, [], CutNumVox);
        PostVoxMap(Grouped.Vox(DotNum).Ind) = 0; % Once cut, no need for PostVoxMap, return the activated voxels to 0 for the next dot entry.

        MaxRawBright = max(Grouped.Vox(DotNum).RawBright);
        PostMaxRawBright = single(max(PostCut(:)));
        ColoMaxRawBright = single(max(ColoCut(:)));
        PostUpperLimit = 200;
        ColoUpperLimit = 200;
        PostScalingFactor = PostUpperLimit/MaxRawBright; %normalized to the dot of interest
        ColoScalingFactor = ColoUpperLimit/ColoMaxRawBright*2; %often dim CtBP2 puncta disspeared when image brightness is adjusted to bright RBC or T6 CtBP2 puncta 
    else
        PostScalingFactor = PostScalingFactor*PostReScalingFactor;
        ColoScalingFactor = ColoScalingFactor*ColoReScalingFactor;
        PostReScalingFactor = 1; %set the Re-scaling factor back to 1
        ColoReScalingFactor = 1; %set the Re-scaling factor back to 1
        DotRepeatFlag = 0; %set the flag back to 0
    end
    
    PostCutScaled = uint8(single(PostCut)*PostScalingFactor);
    ColoCutScaled = uint8(single(ColoCut)*ColoScalingFactor);
    ColoCutLocal = uint8(single(ColoCutScaled)*2);
    ZeroCut = zeros(size(PostCut), 'uint8');
    
    ImStk1 = cat(4, PostCutScaled, PostCutScaled, PostCutScaled);
    ImStk2 = cat(4, PostCutScaled, ZeroCut, PostVoxMapCut);
    ImStk3 = cat(4, ColoCutScaled, ColoCutScaled, ColoCutScaled);
    ImStk4 = cat(4, ColoCutLocal, ColoCutLocal, ColoCutLocal);
    ImStk5 = cat(4, PostCutScaled, ColoCutScaled, ZeroCut);
    ImStk6 = cat(4, PostCutScaled, ColoCutLocal, ZeroCut);
    ImStk12 = cat(1, ImStk1, ImStk2);
    ImStk34 = cat(1, ImStk3, ImStk4);
    ImStk56 = cat(1, ImStk5, ImStk6);
    ImStk = cat(2, ImStk12, ImStk34, ImStk56);

    colmap = 'gray(256)';
    FrmPerSec = 5;
    VideoWindowSize = [0 0.03 0.90 0.90];
    colocVideoFig(size(ImStk,3), @(frm) colocRedraw(frm, ImStk, colmap), FrmPerSec, [], [], VideoWindowSize); % if user bins is 10 this results in 100x real speed
    colocRedraw(1, ImStk, colmap);

    set(gcf,'units','centimeters');
    % Place the figure
    set(gcf,'position',[1 3 25 17]);
    % Set figure units back to pixels
    set(gcf,'units','pixel');
    
    %yes, no, save and exit buttons and annotations were added. 2/13/2011 HO
    uicontrol('Style','text','Units','normalized','position',[.1,.97,.2,.02],'String',['TotalNumDots: ' num2str(ColocManual.TotalNumDotsManuallyColocAnalyzed)]);
    uicontrol('Style','text','Units','normalized','position',[.35,.97,.2,.02],'String',['Dot number: ' num2str(DotNum)]);
    uicontrol('Style','text','Units','normalized','position',[.6,.97,.2,.02],'String',['Remaining dot number: ' num2str(NumRemainingDots)]);
    uicontrol('Style','text','Units','normalized','position',[.09,.94,.13,.02],'String',[ColocManual.Source]);
    uicontrol('Style','text','Units','normalized','position',[.39,.94,.13,.02],'String',[ColocManual.Fish1]);

    uicontrol('Style','Pushbutton','Units','normalized','position',[.91,.25,.08,.08],...
        'String','Coloc','CallBack','ColocManual.ColocFlag(ColocManual.ListDotIDsManuallyColocAnalyzed==DotNum)=1; uiresume');
    uicontrol('Style','Pushbutton','Units','normalized','position',[.91,.15,.08,.08],...
        'String','Not coloc','CallBack','ColocManual.ColocFlag(ColocManual.ListDotIDsManuallyColocAnalyzed==DotNum)=2; uiresume');
    uicontrol('Style','Pushbutton','Units','normalized','position',[.91,.45,.08,.08],...
        'String','Save','Callback','save([TPN ''ColocManual.mat''], ''ColocManual'');uiwait(msgbox(''Progress saved.''));');
    uicontrol('Style','Pushbutton','Units','normalized','position',[.91,.55,.08,.08],...
        'String','Exit','Callback','clear all;close all;clc');
    uicontrol('Style','Pushbutton','Units','normalized','position',[.91,.65,.08,.08],...
        'String','False Dot','CallBack','ColocManual.ColocFlag(ColocManual.ListDotIDsManuallyColocAnalyzed==DotNum)=3; uiresume');
    uicontrol('Style','Pushbutton','Units','normalized','position',[.91,.75,.08,.08],...
        'String','Reset Last Dot','CallBack','ColocManual.ColocFlag(ColocManual.ListDotIDsManuallyColocAnalyzed==LastDotNum)=0; uiwait(msgbox(''Last dot will be examined again.''))');
    
    uicontrol('Style','Pushbutton','Units','normalized','position',[.24,.94,.02,.02],...
        'String','+','CallBack','DotRepeatFlag=1; PostReScalingFactor=2; uiresume');
    uicontrol('Style','Pushbutton','Units','normalized','position',[.27,.94,.02,.02],...
        'String','-','CallBack','DotRepeatFlag=1; PostReScalingFactor=0.5; uiresume');
    uicontrol('Style','Pushbutton','Units','normalized','position',[.54,.94,.02,.02],...
        'String','+','CallBack','DotRepeatFlag=1; ColoReScalingFactor=2; uiresume');
    uicontrol('Style','Pushbutton','Units','normalized','position',[.57,.94,.02,.02],...
        'String','-','CallBack','DotRepeatFlag=1; ColoReScalingFactor=0.5; uiresume');
    
    uiwait;
       
    close all;
    LastDotNum = DotNum; %register this dot to retrieve the last dot when you push a wrong button.
end

save([TPN 'ColocManual.mat'], 'ColocManual'); 

% Add stats so that you can remember ColocFlag of 1 is coloc, etc.
ColocManual.NumDotsColoc = length(find(ColocManual.ColocFlag == 1));
ColocManual.NumDotsNonColoc = length(find(ColocManual.ColocFlag == 2));
ColocManual.NumFalseDots = length(find(ColocManual.ColocFlag == 3));
ColocManual.ColocRate = ColocManual.NumDotsColoc/(ColocManual.NumDotsColoc+ColocManual.NumDotsNonColoc);
ColocManual.FalseDotRate = ColocManual.NumFalseDots/(ColocManual.NumDotsColoc+ColocManual.NumDotsNonColoc+ColocManual.NumFalseDots);
ColocManual.ColocRateInclugingFalseDots = ColocManual.NumDotsColoc/(ColocManual.NumDotsColoc+ColocManual.NumDotsNonColoc+ColocManual.NumFalseDots);

save([TPN 'ColocManual.mat'], 'ColocManual'); 
disp(['Colocalization Rate: ' num2str(ColocManual.ColocRate)]);




