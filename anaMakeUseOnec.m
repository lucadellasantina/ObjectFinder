function[] = anaMakeUseOnec(Dots, Skel, Settings)
TPN = Settings.TPN;
xyum=Settings.ImInfo.xyum;
zum=Settings.ImInfo.zum;

AllSegCut = cat(2, Skel.SegStats.Seg(:,2,:), ...
                   Skel.SegStats.Seg(:,1,:), ...
                   Skel.SegStats.Seg(:,3,:));

DPos=round(Dots.Pos);
DPos(:,1:2)=DPos(:,1:2)*xyum; DPos(:,3)=DPos(:,3)*zum;
Cent=Dots.ImInfo.CBpos;
Cent=Cent*xyum;
Use.DPos=DPos;
Use.Cent=Cent;

%Extract Dend positions
Mids=mean(AllSegCut,3); % segment xyz position calculated as mean of two node positions
Length=sqrt((AllSegCut(:,1,1)-AllSegCut(:,1,2)).^2 ...
          + (AllSegCut(:,2,1)-AllSegCut(:,2,2)).^2 ...
          + (AllSegCut(:,3,1)-AllSegCut(:,3,2)).^2);
Use.Mids=Mids;
Use.Length=Length;

% Store stratification level of each segment if you have SratificationIndMap.mat HO 10/15/2011
if isfield(Skel.FilStats, 'SkelStratification')
    Edges=Skel.FilStats.aEdges+1;
    SegStrat=[Skel.FilStats.SkelStratification(Edges(:,1)); Skel.FilStats.SkelStratification(Edges(:,2))];
    SegStrat=SegStrat';
    MidsStrat = Skel.FilStats.EdgeStratification;
    Use.SegStrat = SegStrat;
    Use.MidsStrat = MidsStrat;
end

Nearest = zeros(size(DPos, 1),1);
for i = 1:size(DPos,1)
    Ndist=dist(Mids,DPos(i,:)); %find dist from dot to all nodes
    Near=min(Ndist); %find shortest distance
    Nearest(i)=find(Ndist==Near,1); %get node at that distance
end
NN=Mids(Nearest,:); %assign that node to NearestNode list for dots
Use.NN=NN;

% Store stratification level of each segment if you have SratificationIndMap.mat HO 10/15/2011
if isfield(Skel.FilStats, 'SkelStratification')
    Use.NNStrat = MidsStrat(Nearest);
end

clear NN OK DPos Cent Dots
clear Mids Length AllSgeCut

% Extract Depth restrictions
if exist([TPN 'data' filesep 'Results.mat'], 'file')
    load([TPN 'data' filesep 'Results.mat'])
    clear Top Bottom
    Use.Top = zeros(size(Results.Arbor,2),1);
    Use.Bottom = zeros(size(Results.Arbor,1));
    for i = 1: size(Results.Arbor,2)
        Use.Top(i)=Results.Arbor(i).Top;
        Use.Bottom(i)=Results.Arbor(i).Bottom;
    end
end
save([TPN 'Use.mat'],'Use');

end

