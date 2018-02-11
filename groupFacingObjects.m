%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016,2017,2018 Luca Della Santina
%
%  This program is free software: you can redistribute it and/or modify
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
function[Grouped] = groupFacingObjects(Settings, Dots, Filter)
% Collect information from dots that passed thresholding
%colormap colorcube;
TPN = Settings.TPN;
Pass = Filter.passF; % If not available PassI use dots passing SG threshold
IDs=find(Pass);
ImSize=Dots.ImSize;
nearby = round(1/Settings.ImInfo.xyum);%10;  %Distance at which faces are looked at %look up to 1um nearby, changed from 10 to 1/Settings.ImInfo.xyum to deal with images with different resolution HO 6/28/2010
maxContact = 0.3; % maximum faces/volume to be independent dot

%% Determine distance from dot to dot
fprintf('Grouping objects facing each other ... ');
Dists = zeros(length(IDs),length(IDs));
for i = 1: length(IDs)
   Dists(i,:) = dist2(Dots.Pos(IDs,:),Dots.Pos(IDs(i),:)); %[i,j] element in Dists will be the distance between i-th dot and j-th dot in a unit of voxel number.  
end
[x, y] = find((Dists > 0) & (Dists < nearby)); % pick pair of dots whose distance is between 0 and nearby.

idX=IDs(x); %idX will be IDs of one dot in each pair of dots
idY=IDs(y); %idY will be IDs of the other dot in each pair of dots

% Count shared faces of nearby dots
faces = zeros(length(idX),1);
for i = 1: length(idX) %go through individual idX-idY pair
   cDotX = Dots.Vox(idX(i)).Pos;
   cDotY = Dots.Vox(idY(i)).Pos;
   face = zeros(size(cDotX,1),1);
   for v = 1: size(cDotX,1) %go through individual voxels in the dot specified by idX(i) and calculate faces with all the voxels in the dot specified by idY(i)
    diff = [cDotY(:,1)-cDotX(v,1)  cDotY(:,2)-cDotX(v,2) cDotY(:,3)-cDotX(v,3)];
    face(v) = sum(sum(abs(diff),2)<2); %this condition will be met only when one voxel sits right next to the other in 6 primany neighboring directions
   end  % so face(v) counts number of voxels in the idY(i) dot that faces a voxel 'v' in the idX(i) dot
    faces(i) = sum(face); %faces(i) will be the sum of all of these countings for idX(i) dot
end

% Form new groups if too much contact between pairs of dots
newGroup = [];
contactRat = zeros(1, length(faces));
for i = 1:length(faces)
    Vol = (Dots.Vol(idX(i))+Dots.Vol(idY(i)))/2; %HO 6/8/2010
    contactRat(i) = faces(i)/Vol; %calculate the ratio of faces over the volume of the puncta
    if contactRat(i) > maxContact
        newGroup(size(newGroup,1)+1,:) = [idX(i), idY(i)];
    end
end

% Organize groups
depleteIDs= newGroup;
groups = {};
gNum = 0;
while sum(depleteIDs(:))
   gNum = gNum+1;
   newest = depleteIDs(find(depleteIDs>0,1)); % do the first one in the remaining list
   foundNew = 1;
   groups{gNum} = newest;
   while foundNew
       foundNew = 0;
       for n = 1: length(newest)
            [grby, ~] = find(depleteIDs == newest(n)); %more than one newest(n) could be in deplateIDs, and grby and grbx will be the row and the column indices
            graby = [grby;grby]; %this will repeat the grby, make the column vector twice longer
       end
       if ~isempty(graby)
           grabbed = newGroup(graby,:); 
           grabbed = unique(grabbed(:)); %unique!? what is the grby repeat for?
           grabbed = setdiff(grabbed, newest); %find the ID of all the dots that have significant amt of facing with the 'newst' dot
           groups{gNum} = [groups{gNum} grabbed'];   
           depleteIDs(graby,:)=0; %convert already-checked dot pairs to 0 so that it avoids find(depleteIDs>0,1) line above
           newest = grabbed;
           foundNew = 1;
       end
   end
end

nonGroupedIDs = setdiff(IDs,newGroup(:));
for i = 1:length(nonGroupedIDs)
   groups{length(groups)+1} = nonGroupedIDs(i); 
end

%% Create merged dots
for i = 1:length(groups)
    Grouped.ids{i} = [];
    Grouped.Vox(i).Pos = [];
    Grouped.Vox(i).Ind = [];
    Grouped.Vox(i).RawBright = [];
end
Grouped.Pos = zeros(length(groups),3);
Grouped.Vol = zeros(1,length(groups));
Grouped.ITMax = zeros(1,length(groups));
Grouped.ItSum = zeros(1,length(groups));
Grouped.MeanBright = zeros(1,length(groups));
     
for i = 1:length(groups)
    Grouped.ids{i} = groups{i};
    for g= 1:length(groups{i})
        Grouped.Vox(i).Pos=[Grouped.Vox(i).Pos ; Dots.Vox(groups{i}(g)).Pos];
        Grouped.Vox(i).Ind=[Grouped.Vox(i).Ind ; Dots.Vox(groups{i}(g)).Ind];
        Grouped.Vox(i).RawBright=[Grouped.Vox(i).RawBright ; Dots.Vox(groups{i}(g)).RawBright];
    end
    Grouped.Pos(i,:) = mean(Grouped.Vox(i).Pos,1); % mean of all the voxels is Pos (so, it's center of mass.)
    Grouped.Vol(i) = length(Grouped.Vox(i).Ind); %6/29/2010 HO
    Grouped.ITMax(i) = max(Dots.ITMax(groups{i})); %6/29/2010 HO
    Grouped.ItSum(i) = sum(Dots.ItSum(groups{i})); %6/29/2010 HO
    Grouped.MeanBright(i) = mean(Grouped.Vox(i).RawBright); %6/29/2010 HO
end

Grouped.ImInfo = Settings.ImInfo;
Grouped.Num = length(groups); %6/29/2010 HO
fprintf('DONE\n');
disp(['Number of objects validated after grouping: ' num2str(length(groups))]);

%% Draw gouped dots 
maxSum=zeros(ImSize(1),ImSize(2)); %Dots.ImSize to Grouped.ImSize 6/29/2010 HO
maxID1=maxSum; maxID2 = maxSum; maxID3 = maxSum;

for i = 1:Grouped.Num %size(Grouped.DPos,1) to Grouped.Num 6/29/2010 HO
    Pos=Grouped.Vox(i).Pos; %Grouped.Vox to Grouped.Vox.Pos 6/29/2010 HO
    PosI=sub2ind(ImSize(1:2),Pos(:,1),Pos(:,2)); %just ImSize to Grouped.ImSize 6/29/2010 HO
    maxID1(PosI)=rand*200+50;  
    maxID2(PosI)=rand*200+50;  
    maxID3(PosI)=rand*200+50;   
    maxSum(PosI)=maxSum(PosI)+1;
end

MaxC=maxID1+(maxSum>1)*1000;
MaxC(:,:,2)=maxID2+(maxSum>1)*1000;
MaxC(:,:,3)=maxID3+(maxSum>1)*1000;
MaxC=uint8(MaxC);

imwrite(MaxC,[TPN 'images' filesep 'Grouped.tif'],'Compression','none');
end

function[d]=dist2(A,B)
%finds distance between two vectors in form A (n,3,n) and B (1,3)
A2=zeros(size(A,1),3,size(A,3));
B2=zeros(size(B,1),3);
A2(:,1:size(A,2),:)=A;
B2(:,1:size(B,2))=B;
A=A2;
B=B2;
d=sqrt((A(:,1,:)-B(1)).^2 + (A(:,2,:)-B(2)).^2 + (A(:,3,:)-B(3)).^2);
end