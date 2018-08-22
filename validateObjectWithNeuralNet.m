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

% Create or reset NeuralNet folder in current experiment folder
if ~isfolder([pwd filesep 'NeuralNet'])
    mkdir([pwd filesep 'NeuralNet']);
else
    rmdir([pwd filesep 'NeuralNet'], 's');
    mkdir([pwd filesep 'NeuralNet']);
end

%Save the voxels of each Object as tif in the NeuralNet folder
disp('Creating NeuralNet validation dataset from current objects');
for i=1:length(Dots.Vox)
    minPt = min(Dots.Vox(i).Pos(:,1:3));
    maxPt = max(Dots.Vox(i).Pos(:,1:3));
    imMat = zeros(maxPt-minPt+1);
    
    for j=1:size(Dots.Vox(i).Pos, 1)
        pt = Dots.Vox(i).Pos(j,:) - minPt + 1;
        imMat(pt(1),pt(2),pt(3)) = Dots.Vox(i).RawBright(j); %<--- Must be better way to do this
    end
    
    % Create maximum intensity projections (MIP) along cardinal axes
    a = max(imMat,[],3);
    a = imresize(a/255, [227 227]);
    b = squeeze(max(imMat,[],1));
    b = imresize(b/255, [227 227]);
    c = squeeze(max(imMat,[],2));
    c = imresize(c/255, [227 227]);
    % Encode each MIP as an R-G-B channel to save the final image as a single TIF file
    I = cat(3,a,b,c);
    imwrite(I, [pwd filesep 'NeuralNet' filesep Dots.Name '_' num2str(i) '.tif']);
end


% Validate Objects with NeuralNet. Prediction == either 'Object' or 'Noise'
disp(['Validating objects using ' NeuralNet.Name]);
Data = imageDatastore([pwd filesep 'NeuralNet']);
[Prediction, Probability] = classify(NeuralNet.netTransfer, Data); %#ok
disp(['Objects identified: ' num2str(sum((Prediction=='Object'))) '/' num2str(length(Prediction))]);

% assignin('base', 'Prediction', Prediction);
% assignin('base', 'NeuralNet', NeuralNet);
% assignin('base', 'Dots', Dots);
% assignin('base', 'Data', Data);

Filter = Dots.Filter;
Filter.passF = (Prediction == 'Object');
end