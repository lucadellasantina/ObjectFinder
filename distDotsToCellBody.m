function[Dots] = distDotsToCellBody(Dots, Skel, Settings)
% This program calculate the position of the center of cell body as mean of
% all voxels assigned as a cell body region in Amira (assigned as 2).
% Then, calculate distance from this cell body center to individual dots.

% New version will assume the center of cell body as a starting point of
% marching during Imaris filament skeletonization whose location is stored
% in Skel.FilStats.SomaPtXYZ. HO 1/10/2010

%Find cell body
xyum=Settings.ImInfo.xyum; %changed to reflect structure format of ImInfo HO 1/5/2010
zum=Settings.ImInfo.zum; %changed to reflect structure format of ImInfo HO 1/5/2010
CBpos = [ceil(Skel.FilStats.SomaPtXYZ(2)/xyum) ceil(Skel.FilStats.SomaPtXYZ(1)/xyum) ceil(Skel.FilStats.SomaPtXYZ(3)/zum)];
Dots.ImInfo.CBpos=CBpos;

CBpos=Dots.ImInfo.CBpos; %open and scale
CBpos(1:2)=CBpos(1:2)*xyum; CBpos(3)=CBpos(3)*zum;
Dpos=Dots.Pos; Dpos(:,1:2)=Dpos(:,1:2)*xyum; Dpos(:,3)=Dpos(:,3)*zum;

Dist2CB=dist(Dpos,CBpos);
Dots.Dist2CB=Dist2CB;
end




