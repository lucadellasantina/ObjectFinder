%% Clarinet: Electrophysiology time series analysis
% Copyright (C) 2018-2024 Luca Della Santina
%
%  This file is part of Clarinet
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% This software is released under the terms of the GPL v3 software license
%

function structOut = editStruct(structIn, title, prompt)
%% Edit structure using a dynamically generated GUII
% Enter the Structure first.  optionally enter title, and then prompts
% Data type (num or string) should be preserved

fnames = fieldnames(structIn);
if nargin < 3
    prompt = fnames;
end
if nargin < 2
    title = 'Settings';
end

nLines = 1;
for i = 1:length(fnames)
    var = structIn.(fnames{i});
    if ischar(var)
        notstr(i)   = 0;
        gVars{i}    = var;
    else
        gVars{i}    = num2str(var);
        notstr(i)   = 1;
    end
end

gVars = inputdlg(prompt,title,nLines,gVars);
if numel(gVars) == 0
    structOut = [];
    return
else
    
pause(0.1);

structOut = struct;
for i = 1:length(fnames)
    if notstr(i)
        structOut.(fnames{i}) = str2double(gVars{i});
    else
        structOut.(fnames{i}) = gVars{i};
    end
end
end