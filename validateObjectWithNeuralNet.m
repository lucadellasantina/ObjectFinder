%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016,2017,2018 Luca Della Santina
%
%  This file is part of ObjectFinder
%
%  ObjectFinder is free software: you can redistribute it and/or modify
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
function Filter = validateObjectWithNeuralNet(Dots, NeuralNet)
%% Classify objects using neural network (outcome == 'Object' or 'Noise')
tic;
sz = NeuralNet.Layers.Layers(1).InputSize;     
Filter = Dots.Filter;

disp(['Validating objects using ' NeuralNet.Name]);
for i = 1:length(Dots.Vox)
    % Reconstruct the image of current object from raw brightness values
    minPt = min(Dots.Vox(i).Pos(:,1:3));
    maxPt = max(Dots.Vox(i).Pos(:,1:3));
    imMat = zeros(maxPt-minPt+1, 'uint8');
    for j=1:size(Dots.Vox(i).Pos, 1)
        pt = Dots.Vox(i).Pos(j,:) - minPt + 1;
        imMat(pt(1),pt(2),pt(3)) = Dots.Vox(i).RawBright(j);
    end
    
    % Treat differently 2D vs 3D images
    if size(imMat, 3) == 1
        % 2D image: Resize image and encode as RGB
        x = imresize(imMat, [sz(1) sz(2)]);
        I = cat(3,x,x,x);
    else
        % 3D image: Create MIPs along cardinal axes, resize and combine into RGB
        z = imresize(squeeze(max(imMat,[],3)), [sz(1) sz(2)]);
        y = imresize(squeeze(max(imMat,[],1)), [sz(1) sz(2)]);
        x = imresize(squeeze(max(imMat,[],2)), [sz(1) sz(2)]);
        I = cat(3,z,y,x);
    end

    % Classify using pretrained neural network
    Filter.passF(i) = (classify(NeuralNet.Net, I) == 'Object');
end
disp(['Done in ' num2str(toc) ' seconds, valid objects: ' num2str(numel(find(Filter.passF))) ' / ' num2str(numel(Filter.passF))]);
end