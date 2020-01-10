%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2020 Luca Della Santina
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

function Skel = loadSkel(UID, FieldNames)
%% Load objects matching ObjName
if nargin <2
    FieldNames = {};
end

Skel = [];
files = dir([pwd filesep 'skeletons' filesep '*.mat']); % List the content of /Objects folder
for d = 1:numel(files)
    [~, fName, ~] = fileparts(files(d).name);
    if strcmp(fName, UID)
        if isempty(FieldNames)
            Skel = load([pwd filesep 'skeletons' filesep files(d).name]);
        else
            Skel = load([pwd filesep 'skeletons' filesep files(d).name], FieldNames{:});
        end
        break;
    end
end

if ~isempty(Skel) && ~isfield(Skel, 'branches')
    Skel.XYZ = Skel.FilStats.aXYZ;
    Skel.SomaPtID = Skel.FilStats.SomaPtID+1;
    Skel.FilStats.aEdges = Skel.FilStats.aEdges - Skel.FilStats.aEdges(1,1) + 1; % shift index edges so that first element starts with 1
    
    % March edges to find matching pairs and recreate the branching pattern
    % For each branch first the march from cell body is computer, then all points in common with previously calculated branches are removed
    % this leaves 1 segment per branch without any diplicate
    vNumberOfSpots = length(Skel.FilStats.aRad); % Store total number of points we need to iterate
    % Find position of terminal and biforcation points in the filament connectivity (aEdges)
    vNumberOfTerminals = 0;
    vTerminals = [];
    vNumberOfForks = 0;
    vForks = [];
    % Start investigating all spots except root (start from position #2 to exclude root)
    for vSpots = 2 : vNumberOfSpots
        vEdge = find(Skel.FilStats.aEdges == vSpots);
        % if current edge is a terminal point of the skeleton, it should be listed once
        if length(vEdge) == 1
            % disp('found a terminal point');
            vNumberOfTerminals = vNumberOfTerminals + 1;
            vTerminals(vNumberOfTerminals) = vSpots; %#ok
        elseif length(vEdge)>2
            % disp('found fork point');
            vNumberOfForks = vNumberOfForks + 1;
            vForks(vNumberOfForks) = vSpots; %#ok
        end
    end
    
    % March backwards from each terminal point to the root in orher to find entire branch path
    vPaths=[]; % keeps an ongoing list of points already assigned to a branch
    for vTerminalIndex = 1:vNumberOfTerminals
        vLength = 1;
        vTerminal = vTerminals(vTerminalIndex); % start from terminal point
        vPath = vTerminal;  % add the terminal point to current path
        
        vFound = true;
        while vFound
            % find among edges which one is connect to current terminal
            % vEdge contains the number to wich vTerminal is connected
            % vSide contains which side of the edge is vTerminal in this connection
            [vEdge, vSide] = find(Skel.FilStats.aEdges == vTerminal);
            
            vFound = false;
            for vNeighborIndex = 1:length(vEdge)
                % looks like is marching both directions here
                vNeighbor = Skel.FilStats.aEdges(vEdge(vNeighborIndex), 3-vSide(vNeighborIndex));
                if vNeighbor < vTerminal
                    vNewTerminal = vNeighbor;
                    vFound = true;
                end
            end
            if vFound
                vLength = vLength + 1;
                vTerminal = vNewTerminal;
                vPath(vLength) = vTerminal;
            end
        end
        
        vPath = fliplr(vPath); % Flip path so that is not going terminal->root but root->terminal instead
        vPath = setdiff(vPath, vPaths); % Remove common part with the paths previously calculated
        vPaths = cat(2,vPaths, vPath); % Add current path to paths
        
        Skel.branches(vTerminalIndex).XYZ = Skel.FilStats.aXYZ(vPath,:);
        Skel.branches(vTerminalIndex).Rad = Skel.FilStats.aRad(vPath);
        %Skel.branches(vTerminalIndex).Edges = [1:vLength-1;2:vLength]';
        Skel.TotalBranches = numel(Skel.branches);
    end
end
end