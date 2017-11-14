function calcPathLengthStats(TPN, Grouped, Skel)

load([TPN 'SkelFiner.mat']);
load([TPN 'Grouped.mat']);

DotPathLengthList = Skel.FilStats.SkelPathLength2Soma(Grouped.ClosestSkelIDs);
EdgePathLengthList = Skel.FilStats.EdgePathLength2Soma;
EdgeLengthList = Skel.SegStats.Lengths;


%DendSkelStratIndList = StratificationIndMap(DDmInd);
EdgePathLengthMax = ceil(max(EdgePathLengthList));

DistBin = 10; %Bin distance is 10 micron by default
DistFromSoma = 5:1:EdgePathLengthMax;
clear NumDots EdgeLengths;
for i=1:length(DistFromSoma);
    NumDots(i) = length(find((DotPathLengthList>DistFromSoma(i)-DistBin/2) & (DotPathLengthList<=DistFromSoma(i)+DistBin/2)));
    EdgeLengths(i) = sum(EdgeLengthList((EdgePathLengthList>DistFromSoma(i)-DistBin/2) & (EdgePathLengthList<=DistFromSoma(i)+DistBin/2)));
end
PoverD = NumDots./EdgeLengths;


cfigure(20,20); set(gcf, 'Color', [0 0 0]);
subplot(3,1,1, 'Color', [0 0 0]), hold on;
plot(DistFromSoma, NumDots, 'w', 'LineWidth', 2);
axis([0 EdgePathLengthMax 0 250]);
set(gca, 'XColor', [1 1 1]); set(gca, 'YColor', [1 1 1]);
title('bin=10um');
xlabel('Path length from cell body (um)');
ylabel('Total number of dots in the bin');
subplot(3,1,2, 'Color', [0 0 0]), hold on;
plot(DistFromSoma, EdgeLengths, 'w', 'LineWidth', 2);
axis([0 EdgePathLengthMax 0 400]);
set(gca, 'XColor', [1 1 1]); set(gca, 'YColor', [1 1 1]);
title('bin=10um');
xlabel('Path length from cell body (um)');
ylabel('Total lengths of dendrites in the bin');
subplot(3,1,3, 'Color', [0 0 0]), hold on;
plot(DistFromSoma, PoverD, 'w', 'LineWidth', 2);
axis([0 EdgePathLengthMax 0 max(1, max(PoverD))]);
set(gca, 'XColor', [1 1 1]); set(gca, 'YColor', [1 1 1]);
title('bin=10um');
xlabel('Path length from cell body (um)');
ylabel('#puncta/um dendrite');

set(gcf,'inverthardcopy','off'); %this will prevent color change back to default upon saving or printing
saveas(gcf, [TPN 'images\DotDend_vs_PathLengthStats'], 'tif');


PathLengthStats.PathLengthBin = DistBin;
PathLengthStats.PathLength2CB = DistFromSoma;
PathLengthStats.PvsPathLength = NumDots;
PathLengthStats.DvsPathLength = EdgeLengths;
PathLengthStats.PoverDvsPathLength = PoverD;

save([TPN 'PathLengthStats.mat'], 'PathLengthStats');


if exist([TPN 'Strat.mat'],'file') %for multistratified RGCs
    load([TPN 'Strat.mat']);
    if length(Strat)>1 %for multistratified RGCs
        DotStratList = Grouped.Stratification;
        EdgeStratList = Skel.FilStats.EdgeStratification;
        cfigure(20,20);
        LineColorList = 'brgyk';
        for a = 2:length(Strat)
            DotPathLengthListArbor = DotPathLengthList((DotStratList>=Strat(a).DendVolOuterLimit) & (DotStratList<=Strat(a).DendVolInnerLimit));
            EdgePathLengthListArbor = EdgePathLengthList((EdgeStratList>=Strat(a).DendVolOuterLimit) & (EdgeStratList<=Strat(a).DendVolInnerLimit));
            EdgeLengthListArbor = EdgeLengthList((EdgeStratList>=Strat(a).DendVolOuterLimit) & (EdgeStratList<=Strat(a).DendVolInnerLimit));
            clear NumDotsArbor EdgeLengthsArbor;
            for i=1:length(DistFromSoma)
                NumDotsArbor(i) = length(find((DotPathLengthListArbor>DistFromSoma(i)-DistBin/2) & (DotPathLengthListArbor<=DistFromSoma(i)+DistBin/2)));
                EdgeLengthsArbor(i) = sum(EdgeLengthListArbor((EdgePathLengthListArbor>DistFromSoma(i)-DistBin/2) & (EdgePathLengthListArbor<=DistFromSoma(i)+DistBin/2)));
            end
            
            PoverDArbor = NumDotsArbor./EdgeLengthsArbor;
            MaxPoverDArbor(a) = max(PoverDArbor);
            
            
            subplot(3,1,1);
            hold on;
            plot(DistFromSoma, NumDotsArbor, LineColorList(a-1), 'LineWidth', 2);
            axis([0 EdgePathLengthMax 0 200]);
            title('bin=10um, blue=Off arbor, red=On arbor');
            xlabel('Path length from cell body (um)');
            ylabel('Total number of dots in the bin');
            subplot(3,1,2);
            hold on;
            plot(DistFromSoma, EdgeLengthsArbor, LineColorList(a-1), 'LineWidth', 2);
            axis([0 EdgePathLengthMax 0 400]);
            title('bin=10um, blue=Off arbor, red=On arbor');
            xlabel('Path length from cell body (um)');
            ylabel('Total lengths of dendrites in the bin');
            subplot(3,1,3);
            hold on;
            plot(DistFromSoma, PoverDArbor, LineColorList(a-1), 'LineWidth', 2);
            axis([0 EdgePathLengthMax 0 max(1, max(MaxPoverDArbor))]);
            title('bin=10um, blue=Off arbor, red=On arbor');
            xlabel('Path length from cell body (um)');
            ylabel('P/D (#puncta/um dendrite) in the bin');
            
            PathLengthStats(a).PathLengthBin = DistBin;
            PathLengthStats(a).PathLength2CB = DistFromSoma;
            PathLengthStats(a).PvsPathLength = NumDotsArbor;
            PathLengthStats(a).DvsPathLength = EdgeLengthsArbor;
            PathLengthStats(a).PoverDvsPathLength = PoverDArbor;
        end
        
        set(gcf,'inverthardcopy','off'); %this will prevent color change back to default upon saving or printing
        saveas(gcf, [TPN 'images\DotDend_vs_PathLengthStats_Bi'], 'tif');
        
        save([TPN 'PathLengthStats.mat'], 'PathLengthStats');
        
        
        %HO added arbor comparison of these parameters 10/18/2011
        %since ectopic OFF arbor of G10 happend in the peripheral, the fair
        %comparison or fair estimate of P/D will be to compare it with ON layer
        %arbor around the same eccentricity because PSD expression tends to go down
        %in the peripheral. So, use dend length of OFF arbor at each eccentricity
        %as weighting factor for ON arbor. Copied from HOGradient and
        %modified.
        
        OffDendPathLengthInnerLimit = find(PathLengthStats(2).DvsPathLength>0, 1, 'first');
        OffDendPathLengthOuterLimit = find(PathLengthStats(2).DvsPathLength>0, 1, 'last');
        PathLengthRange = OffDendPathLengthOuterLimit - OffDendPathLengthInnerLimit + 1;
        PathLengthBin = PathLengthStats(2).PathLengthBin;
        PathLengthNotFitting = mod(PathLengthRange, PathLengthBin);
        if PathLengthNotFitting == 0
            NumBin = (PathLengthRange-PathLengthNotFitting)/PathLengthBin;
            DendAnalysisInnerStartPathLength = OffDendPathLengthInnerLimit+PathLengthBin/2;
        else
            NumBin = (PathLengthRange-PathLengthNotFitting)/PathLengthBin + 1;
            DendAnalysisInnerStartPathLength = OffDendPathLengthInnerLimit + round(PathLengthNotFitting/2);
        end
        
        PathLength = DendAnalysisInnerStartPathLength:PathLengthBin:DendAnalysisInnerStartPathLength+(NumBin-1)*PathLengthBin;
        for i= 1:NumBin
            CorrectPathLengthInd = find(PathLengthStats(2).PathLength2CB==PathLength(i));
            OffP(i) = PathLengthStats(2).PvsPathLength(CorrectPathLengthInd);
            OffD(i) = PathLengthStats(2).DvsPathLength(CorrectPathLengthInd);
            OnP(i) = PathLengthStats(3).PvsPathLength(CorrectPathLengthInd);
            OnD(i) = PathLengthStats(3).DvsPathLength(CorrectPathLengthInd);
        end
        
        OffPTotal = sum(OffP); OffDTotal = sum(OffD);
        OnPTotal = sum(OnP); OnDTotal = sum(OnD);
        OffPoverDTotal = OffPTotal/OffDTotal; OnPoverDTotal = OnPTotal/OnDTotal;
        
        % The other way to calculate this
        if find(OffD == 0 | OnD == 0) %remove path where OFF or ON dendrites don't exist
            ZeroDInd = find(OffD == 0 | OnD == 0);
            OffD(ZeroDInd) = [];
            OffP(ZeroDInd) = [];
            OnD(ZeroDInd) = [];
            OnP(ZeroDInd) = [];
        end
        
        OffPD = OffP./OffD; OnPD = OnP./OnD;
        
        %now replace OffPD with OnPD. So if the On arbor has the same
        %dend length as Off arbor at each eccentricity but different P/D at
        %each eccentricity, what is the total P/D? The number will become much
        %lower than OnPoverDTotal if there are more inner dendrites with higher
        %P/D on the ON arbor.
        OnPoverDTotalWeightedByOffD = sum(OnPD.*OffD)/sum(OffD);
        
        PathLengthStatsBi.OffDendPathLengthFarthestLimit = OffDendPathLengthInnerLimit;
        PathLengthStatsBi.OffDendPathLengthClosestLimit = OffDendPathLengthOuterLimit;
        PathLengthStatsBi.PathLengthBin = PathLengthBin;
        PathLengthStatsBi.PathLength = PathLength;
        PathLengthStatsBi.OffPvsPathLength = OffP;
        PathLengthStatsBi.OffDvsPathLength = OffD;
        PathLengthStatsBi.OffPoverDvsPathLength = OffPD;
        PathLengthStatsBi.OnPvsPathLength = OnP;
        PathLengthStatsBi.OnDvsPathLength = OnD;
        PathLengthStatsBi.OnPoverDvsPathLength = OnPD;
        PathLengthStatsBi.OffPTotal = OffPTotal;
        PathLengthStatsBi.OffDTotal = OffDTotal;
        PathLengthStatsBi.OffPoverDTotal = OffPoverDTotal;
        PathLengthStatsBi.OnPTotal = OnPTotal;
        PathLengthStatsBi.OnDTotal = OnDTotal;
        PathLengthStatsBi.OnPoverDTotal = OnPoverDTotal;
        PathLengthStatsBi.OnPoverDTotalWeightedByOffD = OnPoverDTotalWeightedByOffD;
        
        save([TPN 'PathLengthStatsBi.mat'], 'PathLengthStatsBi');
    end
end
end