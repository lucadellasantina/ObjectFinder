function convertObjectFinderDataV4toV5
%% Convert objectfinder 4.x data format to 5.x data format

load('Dots.mat', 'Dots');
load('Filter.mat', 'Filter');
load('Settings.mat', 'Settings');

Dots.Name                           = 'PSD95';
Dots.Settings                       = Settings;
Dots.Settings.objfinder.blockSearch = true;
Dots.Settings.objfinder.sphericity  = true;
Dots.Settings.ImInfo.PostChName     = 'PSD95.tif';
Dots.Filter                         = Filter;
Dots.Settings.Filter                = Dots.Filter.FilterOpts;

if isfield(Dots, 'Round')    
    Dots        = rmfield(Dots,'Round');
    Dots.Shape  = struct;
    Dots        = fitSphere(Dots, Dots.Settings);
else
    Dots.Shape  = struct;
    Dots        = fitSphere(Dots, Dots.Settings);
end    

Dots.Density = struct;
if exist('Density.mat', 'file')
    load('Density.mat', 'Density');
    Dots.Density = Density;
end

if exist('PathLengthStats.mat', 'file')
    load('PathLengthStats.mat', 'PathLengthStats');
    Dots.Density.PathLengthStats = PathLengthStats;
end

Dots.Skel = struct;
if isfield(Dots, 'Dist2CB')
    Dots.Skel.Dist2CB           = Dots.Dist2CB;
    Dots.Skel.ClosestSkelIDs    = Dots.ClosestSkelIDs;
    Dots.Skel.ClosestSkelDist   = Dots.ClosestSkelDist;
    Dots.Settings.ImInfo.CBpos  = Dots.ImInfo.CBpos;
    
    Dots = rmfield(Dots,'Dist2CB');
    Dots = rmfield(Dots,'ClosestSkelIDs');
    Dots = rmfield(Dots,'ClosestSkelDist');
    Dots = rmfield(Dots,'ImInfo');
end

Dots.Coloc = struct;
if exist('Coloc.mat', 'file')
    load('Coloc.mat', 'Coloc');
    Dots.Coloc = Coloc;
end

Dots.NN = struct;
save('Dots.mat', 'Dots');


clear Density Filter PathLengthStats Settings Coloc
delete('Dend.mat');
delete('Post.mat');
delete('Filter.mat');
delete('Density.mat');
delete('PathLengthStats.mat');
end