%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2024 Luca Della Santina
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
function Dots = inspectVolume3D(Post, Dots, Filter)

    % Default parameter values
    passI      = Filter.passF;    % Initialize temporary filter
    thresh     = 0;               % Initialize thresholds
    thresh2    = 0;               % Initialize thresholds
	
	% Initialize GUI
	figure('Name','3D Volume inspector','NumberTitle','off','Color',[.3 .3 .3], 'MenuBar','none', 'Units','normalized');
    set(gcf,'units', 'normalized', 'position', [0.05 0.1 0.9 0.76]);

    % Visualize volume
    Objs = getFilteredObjects(Dots, Dots.Filter);
    ObjsMask = zeros(size(Post.I), 'uint8');
    for i = 1:numel(Objs.Vox)
        ObjsMask(Objs.Vox(i).Ind) = 1;
    end
    
    VoxSize = [Dots.Settings.ImInfo.xyum, Dots.Settings.ImInfo.xyum, Dots.Settings.ImInfo.zum];
    VoxSizeRatio = VoxSize./VoxSize(1);    
    V = labelvolshow(ObjsMask, Post.I, 'BackGroundColor', [0.15 0.15 0.15], 'ScaleFactors', VoxSizeRatio, 'VolumeOpacity', 0.3, 'VolumeThreshold', 0.4);
    Parent = V.Parent;
    Parent.Position = [0 0 0.9 1];
    
    % Add GUI conmponents
    pnlSettings     = uipanel(  'Title','Objects'   ,'Units','normalized','Position',[.903,.005,.095,.99]); %#ok, unused variable
    txtValidObjs    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.940,.085,.02],'String',['Valid: ' num2str(numel(find(passI)))]);
    txtTotalObjs    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.910,.085,.02],'String',['Total: ' num2str(numel(passI))]); %#ok, unused variable
    txtAction       = uicontrol('Style','text'      ,'Units','normalized','position',[.912,.845,.020,.02],'String','Tool:'); %#ok, unused handle
    cmbAction       = uicontrol('Style','popup'     ,'Units','normalized','Position',[.935,.830,.055,.04],'String', {'Navigate'}); %#ok unused handle
    btnSave         = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.010,.088,.05],'String','Save Objects','Callback',@btnSave_clicked); %#ok, unused variable    
    
    % Primary filter parameter controls
    txtFilter       = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.800,.085,.02],'String','Primary filter'); %#ok, unused variable   
    cmbFilterType   = uicontrol('Style','popup'     ,'Units','normalized','Position',[.907,.750,.060,.04],'String', {'Disabled', 'Score','Volume','Brightness','Roundness','Major Axis Length','Z position'},'Callback', @cmbFilterType_changed);  
    cmbFilterDir    = uicontrol('Style','popup'     ,'Units','normalized','Position',[.970,.750,.025,.04],'String', {'>=', '<='}, 'Visible', 'off'  ,'callback',@cmbFilterDir_changed);            
    btnMinus        = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.715,.025,.04],'String','-','Visible','off'              ,'CallBack',@btnMinus_clicked);    
    txtThresh       = uicontrol('Style','edit'      ,'Units','normalized','Position',[.932,.715,.036,.04],'String',num2str(thresh),'Visible', 'off' ,'CallBack',@txtThresh_changed);
    btnPlus         = uicontrol('Style','Pushbutton','Units','normalized','position',[.970,.715,.025,.04],'String','+','Visible', 'off'             ,'CallBack',@btnPlus_clicked);    

    % Secondary filter parameter controls
    txtFilter2      = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.680,.085,.02],'String','Secondary filter'); %#ok, unused variable   
    cmbFilterType2  = uicontrol('Style','popup'     ,'Units','normalized','Position',[.907,.630,.060,.04],'String',{'Disabled','Score','Volume','Brightness','Roundness','Major Axis Length', 'Z position'},'Callback', @cmbFilterType2_changed);
    cmbFilter2Dir   = uicontrol('Style','popup'     ,'Units','normalized','Position',[.970,.630,.025,.04],'String',{'>=', '<='}, 'Visible', 'off'   ,'callback',@cmbFilterDir_changed);                 
    btnMinus2       = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.595,.025,.04],'String','-','Visible','off'              ,'CallBack',@btnMinus2_clicked);    
    txtThresh2      = uicontrol('Style','edit'      ,'Units','normalized','Position',[.932,.595,.036,.04],'String',num2str(thresh2),'Visible','off' ,'CallBack',@txtThresh2_changed);
    btnPlus2        = uicontrol('Style','Pushbutton','Units','normalized','position',[.970,.595,.025,.04],'String','+','Visible','off'              ,'CallBack',@btnPlus2_clicked);    
    
    % Volume renderingcontrols
    txtVolOpacity   = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.560,.085,.02],'String','Volume opacity:'); %#ok, unused variable
    sldVolOpacity   = uicontrol('Style','slider'    ,'Units','normalized','position',[.907,.530,.085,.02],'String','', 'Min', 0, 'Max', 1, 'Value', 0.3,'CallBack',@sldVolOpacity_changed); %#ok unused handle
    txtVolThreshold = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.480,.085,.02],'String','Volume threshold:'); %#ok, unused variable
    sldVolThreshold = uicontrol('Style','slider'    ,'Units','normalized','position',[.907,.450,.085,.02],'String','', 'Min', 0, 'Max', 1, 'Value', 0.4,'CallBack',@sldVolThreshold_changed);%#ok unused handle
    txtLblOpacity   = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.400,.085,.02],'String','Labels opacity:'); %#ok, unused variable
    sldLblOpacity   = uicontrol('Style','slider'    ,'Units','normalized','position',[.907,.370,.085,.02],'String','', 'Min', 0, 'Max', 1, 'Value', 0.5,'CallBack',@sldLblOpacity_changed); %#ok unused handle
    txtColors       = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.280,.085,.02],'String','Colors:'); %#ok, unused variable
    btnBkgColor     = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.250,.085,.02],'String','Background','CallBack',@btnBkgColor_changed); %#ok unused handle
    btnObjColor     = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.220,.085,.02],'String','Objects','CallBack',@btnObjColor_changed); %#ok unused handle
    
    uiwait;

    function sldVolOpacity_changed(src, event) %#ok, unused arguments
        Value = get(src, 'Value');
        V.VolumeOpacity = Value;
    end
    
    function sldVolThreshold_changed(src, event) %#ok, unused arguments
        Value = get(src, 'Value');
        V.VolumeThreshold = Value;
    end

    function sldLblOpacity_changed(src, event) %#ok, unused arguments
        Value = get(src, 'Value');
        V.LabelOpacity = [0; Value];
    end

    function btnBkgColor_changed(src, event) %#ok, unused arguments
        NewColor = uisetcolor(V.BackgroundColor);
        if numel(NewColor) == 3
            V.BackgroundColor = NewColor;
        end
    end

    function btnObjColor_changed(src, event) %#ok, unused arguments
        NewColor = uisetcolor(V.LabelColor(2,:));
        if numel(NewColor) == 3
            V.LabelColor(2,:) = NewColor;
        end
    end

    function btnSave_clicked(src, event) %#ok, unused arguments
        Filter.passF    = passI;
        save([pwd filesep 'Filter.mat'], 'Filter');
        msgbox('Validated objects saved.', 'Saved', 'help');
    end

    function cmbFilterDir_changed(src,event) %#ok, unused arguments
        applyFilter(thresh, thresh2);
    end

    function btnPlus_clicked(src, event) %#ok, unused arguments
        new_thresh = thresh + 1;
        set(txtThresh,'string',num2str(new_thresh));
        applyFilter(new_thresh, thresh2);
    end

    function btnMinus_clicked(src, event) %#ok, unused arguments
        new_thresh = max(thresh - 1, 0);
        set(txtThresh,'string',num2str(new_thresh));
        applyFilter(new_thresh, thresh2);
    end

    function txtThresh_changed(src, event) %#ok, unused arguments
        thresh_str = get(src,'String');
        new_thresh = str2double(thresh_str);
        applyFilter(new_thresh, thresh2);
    end

    function btnPlus2_clicked(src, event) %#ok, unused arguments
        new_thresh2 = thresh2 + 1;
        set(txtThresh2,'string',num2str(new_thresh2));
        applyFilter(thresh, new_thresh2);
    end

    function btnMinus2_clicked(src, event) %#ok, unused arguments
        new_thresh2 = max(thresh2 - 1, 0);
        set(txtThresh2,'string',num2str(new_thresh2));
        applyFilter(thresh, new_thresh2);
    end

    function txtThresh2_changed(src, event) %#ok, unused arguments
        thresh_str = get(src,'String');
        new_thresh2 = str2double(thresh_str);
        applyFilter(thresh, new_thresh2);
    end

    function cmbFilterType_changed(src, event) %#ok, unused arguments
        switch get(src,'Value')
            case 1 % None
                new_thresh = 0;
                set(cmbFilterDir,'Visible','off');
                set(txtThresh,'Visible','off');
                set(btnPlus,'Visible','off');
                set(btnMinus,'Visible','off');
            case 2 % ITMax
                try
                    new_thresh = Filter.FilterOpts.Thresholds.ITMax;
                    set(cmbFilterDir,'Value',Filter.FilterOpts.Thresholds.ITMaxDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh = ceil(mean(Dots.ITMax)); % mean value;
                end
                set(cmbFilterDir,'Visible','on');
                set(txtThresh,'Visible','on');
                set(btnPlus,'Visible','on');
                set(btnMinus,'Visible','on');                
            case 3 % Volume
                try
                    new_thresh = Filter.FilterOpts.Thresholds.Vol;
                    set(cmbFilterDir,'Value',Filter.FilterOpts.Thresholds.VolDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh = ceil(mean(Dots.Vol)); % mean value;
                end
                set(cmbFilterDir,'Visible','on');
                set(txtThresh,'Visible','on');
                set(btnPlus,'Visible','on');
                set(btnMinus,'Visible','on');                
            case 4 % Brightness
                try
                    new_thresh = Filter.FilterOpts.Thresholds.MeanBright;
                    set(cmbFilterDir,'Value',Filter.FilterOpts.Thresholds.MeanBrightDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh = ceil(mean(Dots.MeanBright)); % mean value;
                end
                set(cmbFilterDir,'Visible','on');
                set(txtThresh,'Visible','on');
                set(btnPlus,'Visible','on');
                set(btnMinus,'Visible','on');                
            case 5 % Oblongness
                try
                    new_thresh = Filter.FilterOpts.Thresholds.Oblong;
                    set(cmbFilterDir,'Value',Filter.FilterOpts.Thresholds.OblongDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh = ceil(mean(Dots.Shape.Oblong)); % mean value;
                end
                set(cmbFilterDir,'Visible','on');
                set(txtThresh,'Visible','on');
                set(btnPlus,'Visible','on');
                set(btnMinus,'Visible','on');                
            case 6 % PrincipalAxisLen
                try
                    new_thresh = Filter.FilterOpts.Thresholds.PrincipalAxisLen;
                    set(cmbFilterDir,'Value',Filter.FilterOpts.Thresholds.PrincipalAxisLenDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh = ceil(mean(Dots.Shape.PrincipalAxisLen)); % mean value;
                end
                set(cmbFilterDir,'Visible','on');
                set(txtThresh,'Visible','on');
                set(btnPlus,'Visible','on');
                set(btnMinus,'Visible','on');                
            case 7 % Z position
                try
                    new_thresh = Filter.FilterOpts.Thresholds.Zposition;
                    set(cmbFilterDir,'Value',Filter.FilterOpts.Thresholds.ZpositionDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh = frame; % Default value is current Z position
                end
                set(cmbFilterDir,'Visible','on');
                set(txtThresh,   'Visible','on');
                set(btnPlus,     'Visible','on');
                set(btnMinus,    'Visible','on');                
        end
        applyFilter(new_thresh, thresh2);
        set(txtThresh,'string',num2str(new_thresh));        
    end

    function cmbFilterType2_changed(src, event) %#ok, unused arguments
        switch get(src,'Value')
            case 1 % None
                new_thresh2 = 0;
                set(cmbFilter2Dir,'Visible','off');
                set(txtThresh2,'Visible','off');
                set(btnPlus2,'Visible','off');
                set(btnMinus2,'Visible','off');
            case 2 % ITMax
                try
                    new_thresh2 = Filter.FilterOpts.Thresholds.ITMax;
                    set(cmbFilter2Dir,'Value',Filter.FilterOpts.Thresholds.ITMaxDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh2 = ceil(mean(Dots.ITMax)); % mean value;
                end
                set(cmbFilter2Dir,'Visible','on');
                set(txtThresh2,'Visible','on');
                set(btnPlus2,'Visible','on');
                set(btnMinus2,'Visible','on');                
            case 3 % Volume
                try
                    new_thresh2 = Filter.FilterOpts.Thresholds.Vol;
                    set(cmbFilter2Dir,'Value',Filter.FilterOpts.Thresholds.VolDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh2 = ceil(mean(Dots.Vol)); % mean value;
                end
                set(cmbFilter2Dir,'Visible','on');
                set(txtThresh2,'Visible','on');
                set(btnPlus2,'Visible','on');
                set(btnMinus2,'Visible','on');                
            case 4 % Brightness
                try
                    new_thresh2 = Filter.FilterOpts.Thresholds.MeanBright;
                    set(cmbFilter2Dir,'Value',Filter.FilterOpts.Thresholds.MeanBrightDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh2 = ceil(mean(Dots.MeanBright)); % mean value;
                end
                set(cmbFilter2Dir,'Visible','on');
                set(txtThresh2,'Visible','on');
                set(btnPlus2,'Visible','on');
                set(btnMinus2,'Visible','on');                
            case 5 % Oblongness
                try
                    new_thresh2 = Filter.FilterOpts.Thresholds.Oblong;
                    set(cmbFilter2Dir,'Value',Filter.FilterOpts.Thresholds.OblongDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh2 = ceil(mean(Dots.Shape.Oblong)); % mean value;
                end
                set(cmbFilter2Dir,'Visible','on');
                set(txtThresh2,'Visible','on');
                set(btnPlus2,'Visible','on');
                set(btnMinus2,'Visible','on');                
            case 6 % PrincipalAxisLen
                try
                    new_thresh2 = Filter.FilterOpts.Thresholds.PrincipalAxisLen;
                    set(cmbFilter2Dir,'Value',Filter.FilterOpts.Thresholds.PrincipalAxisLenDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh2 = ceil(mean(Dots.Shape.PrincipalAxisLen)); % mean value;
                end
                set(cmbFilter2Dir,'Visible','on');
                set(txtThresh2,'Visible','on');
                set(btnPlus2,'Visible','on');
                set(btnMinus2,'Visible','on');                
            case 7 % Z Position
                try
                    new_thresh2 = Filter.FilterOpts.Thresholds.Zposition;
                    set(cmbFilter2Dir,'Value',Filter.FilterOpts.Thresholds.ZpositionDir);
                catch
                    disp('Threshold value or direction not specified on file, using default average value');
                    new_thresh2 = frame; % Deafult value is current Z position
                end
                set(cmbFilter2Dir,'Visible','on');
                set(txtThresh2,'Visible','on');
                set(btnPlus2,'Visible','on');
                set(btnMinus2,'Visible','on');                
        end
        applyFilter(thresh, new_thresh2);
        set(txtThresh2,'string',num2str(new_thresh2));        
    end

    function applyFilter(new_thresh, new_thresh2)
        thresh = new_thresh;
        thresh2 = new_thresh2;
        
        % Apply primary filter criteria if selected        
        switch get(cmbFilterType,'Value')
            case 1 % None
                passI = Filter.passF;
            case 2 % ITMax
                if cmbFilterDir.Value == 1
                    %passI = Filter.passF & (Dots.ITMax >= new_thresh)'; %Filter only previously filtered objects 
                    passI = (Dots.ITMax >= new_thresh)'; % Filter all objects
                else
                    %passI = Filter.passF & (Dots.ITMax <= new_thresh)';
                    passI = (Dots.ITMax <= new_thresh)';
                end
                Filter.FilterOpts.Thresholds.ITMaxDir   = cmbFilterDir.Value;
                Filter.FilterOpts.Thresholds.ITMax      = new_thresh;
            case 3 % Volume
                if cmbFilterDir.Value == 1
                    passI = (Dots.Vol >= new_thresh)';
                else
                    passI = (Dots.Vol <= new_thresh)';
                end
                Filter.FilterOpts.Thresholds.VolDir     = cmbFilterDir.Value;
                Filter.FilterOpts.Thresholds.Vol        = new_thresh;
            case 4 % Brightness
                if cmbFilterDir.Value == 1
                    passI = (Dots.MeanBright >= new_thresh)';
                else    
                    passI = (Dots.MeanBright <= new_thresh)';
                end
                Filter.FilterOpts.Thresholds.MeanBrightDir  = cmbFilterDir.Value;
                Filter.FilterOpts.Thresholds.MeanBright     = new_thresh;
            case 5 % Oblongness
                if cmbFilterDir.Value == 1
                    passI = (Dots.Shape.Oblong >= new_thresh)';
                else    
                    passI = (Dots.Shape.Oblong <= new_thresh)';
                end
                Filter.FilterOpts.Thresholds.OblongDir  = cmbFilterDir.Value;
                Filter.FilterOpts.Thresholds.Oblong     = new_thresh;
            case 6 % Oblongness
                if cmbFilterDir.Value == 1
                    passI = (Dots.Shape.PrincipalAxisLen(:,1)' >= new_thresh)';
                else    
                    passI = (Dots.Shape.PrincipalAxisLen(:,1)' <= new_thresh)';
                end
                Filter.FilterOpts.Thresholds.PrincipalAxisLenDir  = cmbFilterDir.Value;
                Filter.FilterOpts.Thresholds.PrincipalAxisLen     = new_thresh;
            case 7 % Z position
                if cmbFilterDir.Value == 1
                    passI = Dots.Pos(:,3) >= new_thresh;
                else    
                    passI = Dots.Pos(:,3) <= new_thresh;
                end
                Filter.FilterOpts.Thresholds.Zposition  = cmbFilterDir.Value;
                Filter.FilterOpts.Thresholds.Zposition  = new_thresh;
        end
        
        % Apply secondary filter criteria if selected
        switch get(cmbFilterType2,'Value')
            case 2 % ITMax
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.ITMax >= new_thresh2)';
                else
                    passI = passI & (Dots.ITMax <= new_thresh2)';
                end
                Filter.FilterOpts.Thresholds2.ITMaxDir = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds2.ITMax    = new_thresh2;
            case 3 % Volume
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.Vol >= new_thresh2)';
                else
                    passI = passI & (Dots.Vol <= new_thresh2)';
                end
                Filter.FilterOpts.Thresholds2.VolDir = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds2.Vol    = new_thresh2;
            case 4 % Brighness
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.MeanBright >= new_thresh2)';
                else    
                    passI = passI & (Dots.MeanBright <= new_thresh2)';
                end
                Filter.FilterOpts.Thresholds2.MeanBrightDir  = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds2.MeanBright     = new_thresh2;
            case 5 % Oblongness
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.Shape.Oblong >= new_thresh2)';
                else    
                    passI = passI & (Dots.Shape.Oblong <= new_thresh2)';
                end
                Filter.FilterOpts.Thresholds2.OblongDir  = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds2.Oblong     = new_thresh2;
            case 6 % Principal axis length
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.Shape.PrincipalAxisLen(:,1)' >= new_thresh2)';
                else    
                    passI = passI & (Dots.Shape.PrincipalAxisLen(:,1)' <= new_thresh2)';
                end
                Filter.FilterOpts.Thresholds2.PrincipalAxisLenDir  = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds2.PrincipalAxisLen     = new_thresh2;
            case 7 % Z position
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.Pos(:,3) >= new_thresh2);
                else    
                    passI = passI & (Dots.Pos(:,3) <= new_thresh2);
                end
                Filter.FilterOpts.Thresholds2.Zposition  = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds2.Zposition  = new_thresh2;                
        end      
        
        set(txtValidObjs,'string',['Valid Objects: ' num2str(numel(find(passI)))]);
        refreshObjects;
    end

    function refreshObjects
        NewFilter.passF = passI; 
        Objs = getFilteredObjects(Dots, NewFilter);
        Labels = zeros(size(Post.I), 'uint8');
        for ObjNum = 1:numel(Objs.Vox)
            Labels(Objs.Vox(ObjNum).Ind) = 1;
        end
        setVolume(V, Labels);
    end
end