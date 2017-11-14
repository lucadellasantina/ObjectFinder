function [CA] = anaCAsampleUse(Settings)

%7/28/2010 HO loades Results as well because Top and Bottom are in the
%results, not in Use any more.
%7/30/2010 HO save tif images directly under images folder, not under
%subfolder like images\Area..., also name better name.
%8/1/2010 HO removed looping into the second run even when the GC is
%monostratified. Probably better to make a separate program for
%bistratified GCs.

%10/15/2011 HO changed the program from just for monostratified RGC to also
%for bistratified RGCs. I also made a change in the structure of CA.mat and
%the savings of images.

% load info
clear Use DPos Cent Mids Length Top Bottom
TPN = Settings.TPN;
load([TPN 'Use.mat'])
load([TPN 'data' filesep 'Results.mat'])

cfigure(20,20);
cmap=jet(256);
cmap(1,:)=0;
colormap(cmap)
set(gcf,'Colormap',cmap)

DPos=Use.DPos;
Cent=Use.Cent;

Mids=Use.Mids;
Length=Use.Length;

%Top=Use.Top; %Top was not created under Use, but created under Results.Arbor in DotsDD2007.
%Bottom=Use.Bottom; %Bottom was not created, but created under Results.Arbor in DotsDD2007.
Top = zeros(length(Results.Arbor), 1);
Bottom = zeros(length(Results.Arbor), 1);
for arbor = 1:length(Results.Arbor)
    Top(arbor) = Results.Arbor(arbor).Top; %HO 7/8/2010
    Bottom(arbor) = Results.Arbor(arbor).Bottom; %HO 7/8/2010
end

NN=Use.NN;

yM = Settings.ImInfo.yNumVox; % HO 7/8/2010
xM = Settings.ImInfo.xNumVox; % HO 7/8/2010
xyum = Settings.ImInfo.xyum;  % HO 7/8/2010
yM=fix(yM*xyum)+1; % yM is the rounded um length of the image in y direction.
xM=fix(xM*xyum)+1; % xM is the rounded um length of the image in y direction.
Msize=[yM xM];     % 2048*2048 with 0.103um xy pixel size becomes yM=xM=211.

%% create Nearest Node list (nearest node for each dot and distance)
% Get image properties (fix stray data)
DPos(DPos<1)=1;
Mids(Mids<1)=1;
NN(NN<1)=1;
DPos(DPos(:,1)>yM,1)=yM;
Mids(Mids(:,1)>yM,1)=yM;
NN(NN(:,1)>yM,1)=yM;
DPos(DPos(:,2)>xM,2)=xM;
Mids(Mids(:,2)>xM,2)=xM;
NN(NN(:,2)>xM,2)=xM;

%first run (a=1) uses entire arbors, and the second run (a=2) uses only the
%arbors inside the FWHM. Not sure why it needs to run the second time for
%monostratified GC. The second run and the third run are for bistratified GC.
%HO 8/1/2010 removed the loop for monostratified GC this way.
NumLoop = 1;
if size(Top,2)>1
    NumLoop = 1+size(Top,2);
end

if exist([TPN 'Strat.mat'], 'file')
    load([TPN 'Strat.mat']);
end

for a = 1:NumLoop  % Run Arbors
    % This part generates DotMap and DendMap in 1um resolution. DotMap and
    % DendMap will have pixels of values >1 if the number of dots or the
    % length of arbor found in the 1um pixel field is >1. In other words,
    % this part is calculating the density of dots (#/um2) or the density of
    % arbors (um/um2) in each 1um pixel area.
    
    clear sMids sNN
    if a>1
        if isfield(Use, 'MidsStrat') %if my way of stratification was used HO
            sMids=Mids(Use.MidsStrat>=Strat(a).DendVolOuterLimit & Use.MidsStrat<=Strat(a).DendVolInnerLimit, :);
            sNN=NN(Use.NNStrat>=Strat(a).DendVolOuterLimit & Use.NNStrat<=Strat(a).DendVolInnerLimit, :);
            TotalDendLengthStraightCalc=sum(Use.Length(Use.MidsStrat>=Strat(a).DendVolOuterLimit & Use.MidsStrat<=Strat(a).DendVolInnerLimit)); %HO 10/15/2011
        else %use Josh's Top and Bottom made in DotsDD.mat
            sMids=Mids(Mids(:,3)>Top(a-1) & Mids(:,3)<Bottom(a-1),:);
            sNN=NN(NN(:,3)>Top(a-1) & NN(:,3)<Bottom(a-1),:);
            TotalDendLengthStraightCalc = sum(Use.Length(Mids(:,3)>Top(a-1) & Mids(:,3)<Bottom(a-1))); %HO 10/15/2011
        end
        
    else
        sMids=Mids;
        sNN=NN;
        TotalDendLengthStraightCalc = sum(Use.Length); %HO 10/15/2011
    end
    
    TotalDotNumStraightCalc = length(sNN); %HO 10/15/2011
    
    sMids=round(sMids); %This rounds up all the sMids to 1um step.
    sNN=round(sNN); %%This rounds up all the sNN to 1um step.
    
    % Draw Dot maps
    DotMap=zeros(Msize(1),Msize(2)); %DotMap will be 211*211 if the image is 2048*2048 with 0.103um xy pixel size.
    for i=1:size(sNN,1)
        DotMap(sNN(i,1),sNN(i,2))=DotMap(sNN(i,1),sNN(i,2))+1; %if you have >1 dot within the 1um pixel field, you gain more value.
    end
    image(DotMap*200);
    title('Skeletonized dot density map (blue-red = 0-1.28puncta/um2) (1um pixel size)');
    pause(3);
    
    % Draw Dend map
    DendMap=zeros(Msize(1),Msize(2)); %DotMap will be 211*211 if the image is 2048*2048 with 0.103um xy pixel size.
    for i=1:size(sMids,1)
        DendMap(sMids(i,1),sMids(i,2))=DendMap(sMids(i,1),sMids(i,2))+Length(i); %if you have >1 arbor within the 1um pixel field, you gain more value. Also, if the length of arbor is long, you gain more value.
    end
    image(DendMap*100);
    title('Skeletonized dendrite density map (blue-red = 0-2.55um/um2) (1um pixel size)');
    pause(3);
    
    
    % Filter Results
    % This part generates DotFilt and DendFilt, which are the convolution of
    % 10um radius (wide!) disk averaging filter with DotMap and DendMap,
    % respectively. So, instead of each 1um pixel representing the density of
    % dots (#/um2) or the density of arbors (um/um2) WITHIN each 1um pixel area,
    % each 1um pixel in DotFilt and DendFilt represents the average density of
    % dots or arbors within 10um radius circle from that pixel. This is NOT
    % P/A and D/A in Josh's GC figures because the diameter of the disk is
    % 10um, so he must have used Territory-filtered DotFilt and DendFilt to
    % show P/A and D/A. DotSkel and DendSkel are the copies of DotFilt and
    % DendFilt, but bringing the dendritic skeleton to zero for the imaging reason.
    
    % make distance filter
    
    AreaS=10; %filter is 10um RADIUS disk (because one pixel is 1um*1um).
    Disk=fspecial('disk',AreaS); %fspecial geneartes averaging filter. It averages the pixel values in the 21*21 circular area.
    DotFilt=imfilter(DotMap,Disk,'same');
    DendFilt=imfilter(DendMap,Disk,'same');
    BlankFilt=imfilter(double(DendMap>-1000),Disk,'same'); %address image edge problem.
    DotFilt=DotFilt./BlankFilt; %address image edge problem.
    DendFilt=DendFilt./BlankFilt; %address image edge problem.
    
    DendSkel=DendFilt; %copy DendFilt to show the skeleton of dendrites in black in the next line, and preserve DendFilt.
    DendSkel(DendMap>0)=0; %show the skeleton of dendrites in black.
    image(DendSkel*1000)
    title('Dendrite density (blue-red = 0-0.255um/um2) (skeletonized dendrite map filtered by 10um radius disk averaging filter');
    pause(3);
    
    DotSkel=DotFilt; %copy DotFilt to show the skeleton of dendrites in black in the next line, and preserve DotFilt.
    DotSkel(DendMap>0)=0; %show the skeleton of dendrites in black.
    image(DotSkel*2000)
    title('Puncta density (blue-red = 0-0.128puncta/um2) (skeletonized puncta map filtered by 10um radius disk averaging filter');
    pause(3);
    
    
    % Find territory
    % This part generates Dendritic territory, which is the convolution of
    % 5um radius (smaller than DendFilt and DotFilt!) disk averaging filter
    % with DendMap and all the pixels within the territory converted to 1
    % and those outside the territory converted to 0, so the territory acts
    % like a filter when used in the calculation of DotDist and DendDist.
    % DotDist and DendDist is generated by filtering DotFilt and DendFilt
    % with Territory. This is the P/A and D/A GC figures in Josh's paper,
    % and the element-wise DotDist/DendDist is the P/D GC figure. Also mean
    % P/A, mean D/A and mean P/D were calculated by averaging all the pixels
    % WITHIN THE TERRITORY.
    % Compared to using 5um radius to begin with for DendFilt and DotFilt,
    % 10um radius for DotFilt and DendFilt looked smoother and more intuitive
    % in capturing area to look for a density of either puncta or arbors in GCs,
    % also, filled holes in the territory will still have certain low values
    % of P/A, D/A and P/D, which would be why 10um radius was used for DendFilt
    % and DotFilt.
    % Let's check this up with straight calculating them from the number of
    % dots, total arbor length and territory are.
    image(DendMap*100);
    title('Skeletonized dendrite density map (blue-red = 0-2.55um/um2) (1um pixel size)');
    pause(3);
    
    Disk2=fspecial('disk',5);%min(5,min(AreaS/2,1))); %For territory, use 5um RADIUS averaging disk filter.
    TerFilt=imfilter(DendMap,Disk2,'same');
    
    DFlab=bwlabel(TerFilt);
    lSize = zeros(max(DFlab(:)),1);
    for i = 1:max(DFlab(:))
        lSize(i)=size(find(DFlab==i),1);
    end
    
    % HO modified this part because DTA1 G10 had off layer dendrites at the
    % peripheral, which are too far apart from each other to be connected.
    if length(lSize) > 1
        disp('Number of connected objects');
        length(lSize)
        TakeAllOrOneFlag = input('There are more than 1 connected objects. Type 0 for taking the largest, 1 for taking all.\n');
    else
        TakeAllOrOneFlag = 0;
    end
    
    if TakeAllOrOneFlag == 1 %take all
        TerFilt = DFlab>0;
        TerFilt = double(TerFilt);
    else % single object or take largest
        TerFilt=DFlab*0;
        TerFilt(DFlab==find(lSize==max(lSize)))=1; %Take the largest connected object, which must be the GC. Put 1 in the territory.
    end
    
    image(TerFilt*200);
    title('Territory (dendrite skeleton filtered by 5um radius disk)');
    pause(2);
    clear DFlab lSize
    
    % Close
    Csize=round(AreaS/2);
    SE=strel('disk',Csize); %strel puts 1 in all the pixels within the disk filter. Since AreaS is 10, it generates the same 5um radius disk.
    Buf=Csize*2; %need buffer around the image to make imclose to work, I guess.
    [tys, txs] = size(TerFilt);
    BufT=zeros(tys+2*Buf,txs+2*Buf);
    BufT(Buf+1:Buf+tys,Buf+1:Buf+txs)=TerFilt;
    BufC=imclose(BufT,SE); %This will fill (close) all the small holes, but I guess it leaves holes bigger than the size of disk.
    TerC=BufC(Buf+1:Buf+tys,Buf+1:Buf+txs);
    image((TerFilt+TerC)*100);
    title('Territory, small gaps closed by imclose');
    pause(2);
    clear Buf BufT BufC
    
    % Remove holes: this will fill remaining large holes as a territory.
    TerFill=TerC;
    Frame=TerC*0; Frame(1:tys,1)=1; Frame(1:tys,txs)=1; Frame(1,1:txs)=1; Frame(tys,1:txs)=1;
    TerHole=bwlabel(~TerC);
    for i=1:max(TerHole(:))
        Surround=sum(sum((TerHole==i) .* Frame));
        if ~Surround
            TerFill(TerHole==i)=1;
        end
    end
    image(TerFill*100);
    title('Territory, remaining holes were also filled');
    pause(2);
    clear Frame TerHole Surround
    
    % Get Perimeter
    TerPerim=bwperim(TerFill,8);
    image((TerFill+TerPerim)*100);
    title('Perimeter highlighted');
    pause(2);
    
    % Draw Rays (I don't know what this is for.)
    [tpy, tpx]=find(TerPerim);
    TerRay=TerFill*0;
    
    for i = 1: size(tpy,1)
        ydif=Cent(1)-tpy(i); xdif=Cent(2)-tpx(i);
        Long=sqrt(ydif^2 + xdif^2);
        ystep=ydif/Long;
        xstep=xdif/Long;
        
        for l = 1:.5:Long
            TerRay(round(tpy(i)+ystep*l),round(tpx(i)+xstep*l))=1;
        end
    end
    %image(TerRay*100),pause(.01)
    
    Territory=TerFill;
    DotDist=DotSkel.*Territory; %here, DotDist is the masking of DotSkel with Territory, so the dendritic skeleton is black just for imaging reason.
    image(DotDist*2000);
    title('P/A (blue-red = 0-0.128puncta/um2) (filtered puncta map furthered filtered by territory)');
    pause(3);
    
    % Collect Data
    CA.Arbor(a).DotMap=DotMap;
    CA.Arbor(a).DendMap=DendMap;
    CA.Arbor(a).Territory=Territory;
    CA.Arbor(a).DotDist=DotFilt.*Territory; %here for saving DotDist, DotFilt (NOT DotSkel) was filtered by Territory.
    CA.Arbor(a).DendDist=DendFilt.*Territory; %here for saving DendDist, DendFilt (NOT DendSkel) was filtered by Territory.
    CA.Arbor(a).TerPerim=TerPerim;
    CA.Arbor(a).MeanPoverA=mean(DotFilt(Territory>0)); %mean P/A is calculated WITHIN the territory. The name was changed from MeanDotOArea to MeanPoverA HO 10/15/2011
    CA.Arbor(a).MeanDoverA=mean(CA.Arbor(a).DendDist(CA.Arbor(a).Territory>0)); %mean D/A is calculated WITHIN the territory. HO changed the data structure 10/15/2011
    CA.Arbor(a).MeanPoverD=CA.Arbor(a).MeanPoverA/CA.Arbor(a).MeanDoverA; %mean P/D is calculated WITHIN the territory. HO changed the data structure 10/15/2011
    CA.Arbor(a).TotalDendLengthStraightCalc = TotalDendLengthStraightCalc; %HO 10/15/2011
    CA.Arbor(a).TotalDotNumStraightCalc = TotalDotNumStraightCalc; %HO 10/15/2011
    CA.Arbor(a).MeanPoverDStraightCalc = TotalDotNumStraightCalc/TotalDendLengthStraightCalc; %HO 10/15/2011
    CA.Arbor(a).Area = sum(CA.Arbor(a).Territory(:)); %HO changed the data structure 10/15/2011
    
    ShowCell=(CA.Arbor(a).DotDist).* ~CA.Arbor(1).DendMap;
    ShowCell=ShowCell*1000+TerPerim;
    ShowCell=uint8(ShowCell);
    image(ShowCell);
    title('P/A but shown with twice larger density scale (blue-red = 0-0.255puncta/um2) (for saturated image?)');
    pause(3);
    CA.Arbor(a).ShowCell=ShowCell;
    
    
    % The following part was brought into loop 10/15/2011 HO
    [ys, xs]=size(DotMap);
    
    DotDist=CA.Arbor(a).DotDist;
    DendDist=CA.Arbor(a).DendDist;
    DotMap=CA.Arbor(a).DotMap;
    DendMap=CA.Arbor(a).DendMap;
    CA4=zeros(ys*2,xs*2);
    CA4(1:ys,1:xs)=DotDist*2000;
    CA4(1:ys,xs+1:xs*2)=DendDist*600;
    CA4(ys+1:ys*2,1:xs)=((DotMap>0)+(DendMap>0))*100;
    CA4(ys+1:ys*2,xs+1:xs*2)=DotDist./DendDist*256; %Max puncta density is 256/value in this case 256/400 = 0.8 %LDS straghtforward this setting of max puncta density
    image(CA4);
    title('UpLeft:P/A(0-.128dots/um2), UpRight:D/A(0-.425um/um2), LowLeft:skeleton(cyan)+dots(red), LowRight:P/D(0-1 dots/um)');
    CA.Arbor(a).CA4 = CA4;
    CA.Arbor(a);
    colorbar('Ytick',[]); %Adam added color bar 3/11/2011
    axis image; %adding color bar changes image x y dimention, so resize the image.
    axis off %remove the axis
    pause(3);
    
    % Commented out because you can redraw from the saving of CA4
    if a==1
        Name=[TPN 'images\PA_0-pt128PunctaPerUm2&DA_0-pt425UmPerUm2&PD_0-pt64PunctaPerUm.tif'];
    else
        Name=[TPN 'images\PA_0-pt128PunctaPerUm2&DA_0-pt425UmPerUm2&PD_0-pt64PunctaPerUm_Arbor' num2str(a-1) '.tif'];
    end
    
    saveas(gcf,Name) %save figure with title
    
end % Run Arbors

% Manage Information

if size(CA.Arbor,2)>2 %This is for bistratified GC.
    ScaleRG=max(max(CA.Arbor(3).DotDist(:)),max(CA.Arbor(2).DotDist(:)));
    ScaleRG=255/ScaleRG;
    Red=CA.Arbor(2).DotDist*ScaleRG;
    Red=Red+CA.Arbor(2).TerPerim*75;
    Green=CA.Arbor(3).DotDist*ScaleRG;
    Green=Green+CA.Arbor(3).TerPerim*75;
    Blue=~(CA.Arbor(3).Territory & CA.Arbor(2).Territory);
    BiDotDist(:,:,1)=uint8(Red);
    BiDotDist(:,:,2)=uint8(Green);
    BiDotDist(:,:,3)=uint8(Blue)*0;
    CA.BiDotDist=BiDotDist;
    image(BiDotDist);
    title('red = outer arbor, green = inner arbor');
    axis image; axis off %remove the axis
    pause(3);
    
    Name=[TPN 'Images' filesep 'PoverA_Bi.tif'];
    saveas(gcf,Name);
end

save([TPN 'CA.mat'],'CA');
end