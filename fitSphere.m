function[Dots]=fitSphere(Dots, debug)
% HO 6/25/2010 flipped the division to calculate Round.Long, Round.Oblong
% and Round.Compact so that less spherical or less smooth ugly dots get
% lower values, then you can set threshold to take higher values in anaSG.
% However, Compact doesn't work well with small dots which have only
% several voxels because if you think 7-voxel sphere, 1 in the center and 6
% around the center voxel, the average 6-connectivity face per voxel will
% be ~4.3, but if you think 2by2by2 square (8 voxels in total), the value
% will be 3, much lower than sphere. So, actually lots of small dots whose
% Compact values come out large with my flipping the division are noise, so
% the thresholding in anaSG using Compact wouldn't work. This is why the
% old definition somehow worked fine. Just don't include this criteria for
% minimum thresholding in anaSG.
% HO 7/6/2010 modified the generation of reference sphere. Since I use
% different xyz voxel dimentions for different types of imagings, I had to
% increase the volume of reference sphere to work with finer images. Then,
% the old code took forever to generate it, so I modified the code to make
% it faster.


%% Find appropriate mean faces for perfect sphere as reference
% changed from 11*11*11 to 31*31*31 because I do 0.025um xy 0.2um z for the 
% finest image of CtBP2 puncta (so 24 times more possible dot volume 
% compared to 0.103um xy 0.3um z) 6/25/2010

fprintf('Calculating sphericity of each object ... ');
TSphere=zeros(31,31,31);  % Create a matrix to hold the sphere pixels
TSphere2=zeros(33,33,33); % Create a slightly bigger sphere to check in the for loop +-1 pixels away from the perimeter 
TSphere(16,16,16)=1;      % Place 1 in the center point of the sphere
Tdists=bwdist(TSphere);   % Record the distances of each point from the center of the sphere
Tvol = zeros(1,160);      % Tvol(d) stores the number of voxels within the distance of d/10 from the center voxel
meanFaces = zeros(1,160); % Initialize the meanFaces vector

for d=1:160 %if you go >160, the sphere tries to get voxels outside the 31*31*31 3D matrix. HO 6/25/2010
    Near=find(Tdists<(d/10));    % Near are tje pixels within d/10 distance from center. Therefore, for distances d=1:10 only the center point will be identified, then d=11 will identify 6 more voxels around the center voxel.
    Tvol(d)=size(Near,1);        % Tvol(d) will be the number of voxels within the distance of d/10 from the center voxel
    TSphere(Near)=1;             % Fill voxels of the current sphere with ones
    Tperim = bwperim(TSphere,6); % Fill only pixels on the perimether of the sphere
    NearPerim = find(Tperim);    % Store voxel number corresponding to perimeter
    [NearPerimY, NearPerimX, NearPerimZ] = ind2sub(size(TSphere), NearPerim); % Convert voxel numbers into y-x-z coordinates for the perimeter
    FaceCount=0;
    % Explore each voxel at the perimeter, if there is no sphere in the
    % of the perimeter+-1pixel, then increase FaceCount as the real sphere 
    % is a smaller/bigger approximation of this ideal one drawn as flat face.
    % If the sphere ends exactly on the perimeter then numel(FaceCount) == numel(NearPerim)
    
    % Create a slightly bigger sphere to check in the for loop +-1 pixels 
    % away from the perimeter (+0-2 pixels from TSphere2 coordinates)
    TSphere2(2:end-1,2:end-1,2:end-1) = TSphere; 
    
    for n = 1:length(NearPerim) 
        if TSphere2(NearPerimY(n), NearPerimX(n)+1,NearPerimZ(n)+1) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+2, NearPerimX(n)+1,NearPerimZ(n)+1) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+1, NearPerimX(n),NearPerimZ(n)+1) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+1, NearPerimX(n)+2,NearPerimZ(n)+1) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+1, NearPerimX(n)+1,NearPerimZ(n)) == 0
            FaceCount = FaceCount+1;
        end
        if TSphere2(NearPerimY(n)+1, NearPerimX(n)+1,NearPerimZ(n)+2) == 0
            FaceCount = FaceCount+1;
        end
    end
    meanFaces(d)=FaceCount/Tvol(d); 
    % meanFaces: # of faces of the sphere of that radius (d) divided by its volume.
end

c=0;
for v=1:max(Tvol)
    if ~isempty(find(Tvol==v, 1))
        c=c+1;
        tvol(c)=v; % tvol will remove redundancy in Tvol, so tvol would be 1, 7, ...
        % convert volume to meanfaces
        v2f(c)=meanFaces(find(Tvol==v,1)); % find(Tvol==v,1) will take only the 1st one among all Tvol==v, so again removing redundancy in meanFaces
    end
end
RoundFaces=interp1(tvol,v2f,1:max(tvol)); 

if debug
    plot(1:max(tvol), RoundFaces, 'o');
    ylabel('Round faces');
    xlabel('tvol = number of voxels within the distance of d/10 from the center voxel');
end

%% Run Dots
for i = 1:Dots.Num
    % Step-1: Calculate reference distances of each dot along longest axes
 
    Cent = Dots.Pos(i,:);     % Retrieve position of the dot's center
    Vox  = Dots.Vox(i).Pos;   % Retrieve position of each voxel of this dot
    Dist = dist(Vox,Cent);    % Calculate distance of each voxel from center
    MeanD = max(1,mean(Dist));% Calculate average distance from center
    VoxN=Vox/MeanD;           % Normalize each voxel position by MeanD
    
    if size(Vox,1) > 1        % If the dot has more than one voxel
        [~, Sc, latent] = princomp(VoxN);
        Dots.Round.Var(i,:)=latent; % Variance in three component axes.
        Dots.Round.Long(i)=max(.1,latent(2))/latent(1); %ratio of variances between the second longest and longest axes, 1 if perfectly round, <1 if not round
        Dots.Round.Oblong(i)=max(1,abs(max(Sc(:,2))))/max(abs(Sc(:,1))); % Stores distance from center to be the furthest point in the secondary and principal axes, respectively.
        Dots.Round.SumVar(i)=sum(latent);
    else
        Dots.Round.Var(i,:)=[0;0;0];
        Dots.Round.Long(i)=0;
        Dots.Round.SumVar(i)=0;
        Dots.Round.Oblong(i)=1;
    end
    
    %% Step-2: find surface area for each dot
    % (Faces for a given voxel within a punctum will be 0 to 6, 
    % the nubmer of voxels in 6-connectivity neighbors that are
    % outside the punctum)
    for v = 1:size(Dots.Vox(i).Pos,1)
        Conn=dist(Dots.Vox(i).Pos, Dots.Vox(i).Pos(v,:));
        Dots.Vox(i).Faces(v)=6-sum(Conn==1);
    end
    %Dots.Round.histFaces(i,:)=hist(Dots.Vox(i).Faces,0:1:6); %histogram doesn't do anything HO 7/6/2010
    Dots.Round.meanFaces(i)=mean(Dots.Vox(i).Faces);
    
    %HO 6/25/2010 flipped the following division so that more spherical or
    %smooth dots get higher values and ugly dots get lower values.
    %Thresholding in anaSG works well this way. Now Compact is definded as
    %the ratio of the average number of faces (facing outside) per voxel for
    %an ideal spherical dot with the same volume as a given dot over that
    %for the given dot. This value can be >1 or <1, doesn't tell much about
    %how close to sphere if the dots are small, but tells more about how
    %smooth the surface connectivity is. The actually roundness is given
    %better in Round.Long or Round.Oblong.
    %Dots.Round.Compact(i)=Dots.Round.meanFaces(i)/RoundFaces(Dots.Vol(i)); %This was original Compact definition. HO
    Dots.Round.Compact(i)=RoundFaces(Dots.Vol(i))/Dots.Round.meanFaces(i);
end
fprintf('DONE\n');
end