function Grouped = distDotsToSkel(Grouped, Skel, Settings)
SkelYXZ = [Skel.FilStats.aXYZ(:,2), Skel.FilStats.aXYZ(:,1), Skel.FilStats.aXYZ(:,3)];

xyum = Settings.ImInfo.xyum;
zum = Settings.ImInfo.zum;
DotPosYXZ = [Grouped.Pos(:,1)*xyum, Grouped.Pos(:,2)*xyum, Grouped.Pos(:,3)*zum];
minDot2SkelDist = zeros(1, Grouped.Num);
minDot2SkelIDs = zeros(1, Grouped.Num);

for i = 1:Grouped.Num
    Dist=dist(SkelYXZ,DotPosYXZ(i,:));
    [minDot2SkelDist(i), minDot2SkelIDs(i)] = min(Dist);
end

Grouped.ClosestSkelIDs = minDot2SkelIDs;
Grouped.ClosestSkelDist = minDot2SkelDist;
end

