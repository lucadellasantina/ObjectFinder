%% ObjectFinder - Recognize 3D structures in image stacks
%  Copyright (C) 2016-2019 Luca Della Santina
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
function Dots = inspectVolume2D(Post, Dots, Filter)
%%
    % Default parameter values
    CutNumVox   = ceil(size(Post)/8); % Magnify a zoom region of this size
    ImStk       = cat(4, Post, Post, Post); % Create an RGB version of Post
    nFrames     = size(ImStk,3);
    actionType  = 'Select';

    Pos     = ceil([size(ImStk,2)/2, size(ImStk,1)/2, size(ImStk,3)/2]); % Initial position is middle of the stack
    PosRect = ceil([size(ImStk,2)/2-CutNumVox(2)/2, size(ImStk,1)/2-CutNumVox(1)/2]); % Initial position of zoomed rectangle (top-left vertex)
    PosZoom = [-1, -1, -1];             % Initial position in zoomed area
    click   = 0;                        % Initialize click status
    frame   = ceil(nFrames/2);          % Current frame
    passI   = Filter.passF;             % Initialize temporary filter
    thresh  = 0;                        % Initialize thresholds
    thresh2 = 0;                        % Initialize thresholds
    SelObjID= 0;                        % Initialize selected object ID#
	
	% Initialize GUI
	fig_handle = figure('Name','Volume inspector (green: valid object, red: rejected object, blue: selected object)','NumberTitle','off','Color',[.3 .3 .3], 'MenuBar','none', 'Units','norm', ...
		'WindowButtonDownFcn',@button_down, 'WindowButtonUpFcn',@button_up, 'WindowButtonMotionFcn', @on_click, 'KeyPressFcn', @key_press,'windowscrollWheelFcn', @wheel_scroll);
	
	% Add custom scroll bar
	scroll_axes = axes('Parent',fig_handle, 'Position',[0 0 0.9 0.045], 'Visible','off', 'Units', 'normalized');
	axis([0 1 0 1]); axis off
	scroll_bar_width = max(1 / nFrames, 0.01);
	scroll_handle = patch([0 1 1 0] * scroll_bar_width, [0 0 1 1], [.8 .8 .8], 'Parent',scroll_axes, 'EdgeColor','none', 'ButtonDownFcn', @on_click);

    % Add GUI conmponents
    set(gcf,'units', 'normalized', 'position', [0.05 0.1 0.90 0.76]);
    pnlSettings     = uipanel(  'Title','Objects'   ,'Units','normalized','Position',[.903,.005,.095,.99]); %#ok, unused variable
    txtValidObjs    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.940,.085,.02],'String',['Valid: ' num2str(numel(find(passI)))]);
    txtTotalObjs    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.910,.085,.02],'String',['Total: ' num2str(numel(passI))]); %#ok, unused variable
    txtAction       = uicontrol('Style','text'      ,'Units','normalized','position',[.912,.845,.020,.02],'String','Tool:'); %#ok, unused handle
    cmbAction       = uicontrol('Style','popup'     ,'Units','normalized','Position',[.935,.830,.055,.04],'String', {'Select (s)'},'Callback', @cmbAction_changed);
    chkShowObjects  = uicontrol('Style','checkbox'  ,'Units','normalized','position',[.912,.880,.085,.02],'String','Colors (spacebar)', 'Value',1,'Callback',@chkShowObjects_changed);
    txtZoom         = uicontrol('Style','text'      ,'Units','normalized','position',[.925,.230,.050,.02],'String','Zoom level:'); %#ok, unused variable
    btnZoomOut      = uicontrol('Style','Pushbutton','Units','normalized','position',[.920,.170,.030,.05],'String','-'                              ,'Callback',@btnZoomOut_clicked); %#ok, unused variable
    btnZoomIn       = uicontrol('Style','Pushbutton','Units','normalized','position',[.950,.170,.030,.05],'String','+'                              ,'Callback',@btnZoomIn_clicked); %#ok, unused variable
    btnSave         = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.010,.088,.05],'String','Save current objects'           ,'Callback',@btnSave_clicked); %#ok, unused variable    
    
    % Primary filter parameter controls
    txtFilter       = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.800,.085,.02],'String','Primary filter type'); %#ok, unused variable   
    cmbFilterType   = uicontrol('Style','popup'     ,'Units','normalized','Position',[.907,.750,.060,.04],'String', {'Disabled', 'Score','Volume','Brightness','Roundness','Major Axis Length','Z position'},'Callback', @cmbFilterType_changed);  
    cmbFilterDir    = uicontrol('Style','popup'     ,'Units','normalized','Position',[.970,.750,.025,.04],'String', {'>=', '<='}, 'Visible', 'off'  ,'callback',@cmbFilterDir_changed);            
    btnMinus        = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.715,.025,.04],'String','-','Visible','off'              ,'CallBack',@btnMinus_clicked);    
    txtThresh       = uicontrol('Style','edit'      ,'Units','normalized','Position',[.932,.715,.036,.04],'String',num2str(thresh),'Visible', 'off' ,'CallBack',@txtThresh_changed);
    btnPlus         = uicontrol('Style','Pushbutton','Units','normalized','position',[.970,.715,.025,.04],'String','+','Visible', 'off'             ,'CallBack',@btnPlus_clicked);    

    % Secondary filter parameter controls
    txtFilter2      = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.680,.085,.02],'String','Secondary filter type'); %#ok, unused variable   
    cmbFilterType2  = uicontrol('Style','popup'     ,'Units','normalized','Position',[.907,.630,.060,.04],'String',{'Disabled','Score','Volume','Brightness','Roundness','Major Axis Length', 'Z position'},'Callback', @cmbFilterType2_changed);
    cmbFilter2Dir   = uicontrol('Style','popup'     ,'Units','normalized','Position',[.970,.630,.025,.04],'String',{'>=', '<='}, 'Visible', 'off'   ,'callback',@cmbFilterDir_changed);                 
    btnMinus2       = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.595,.025,.04],'String','-','Visible','off'              ,'CallBack',@btnMinus2_clicked);    
    txtThresh2      = uicontrol('Style','edit'      ,'Units','normalized','Position',[.932,.595,.036,.04],'String',num2str(thresh2),'Visible','off' ,'CallBack',@txtThresh2_changed);
    btnPlus2        = uicontrol('Style','Pushbutton','Units','normalized','position',[.970,.595,.025,.04],'String','+','Visible','off'              ,'CallBack',@btnPlus2_clicked);    

    % Selected object info
    txtSelObj       = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.560,.085,.02],'String','Selected Object info'); %#ok, unused variable
    txtSelObjID     = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.530,.085,.02],'String','ID# :');
    txtSelObjITMax  = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.500,.085,.02],'String','Score : ');
    txtSelObjVol    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.470,.085,.02],'String','Volume : ');
    txtSelObjBright = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.440,.085,.02],'String','Brightness : ');
    txtSelObjRound  = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.410,.085,.02],'String','Roundness : ');
    txtSelObjLength = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.380,.085,.02],'String','Length : ');
    txtSelObjValid  = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.350,.085,.02],'String','Validated : ');    
    btnToggleValid  = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.300,.088,.04],'String','Change Validation (v)'          ,'Callback',@btnToggleValid_clicked); %#ok, unused variable
    
	% Main drawing and related handles
	axes_handle     = axes('Position',[0 0.03 0.90 1]);
	frame_handle    = 0;
    rect_handle     = 0;    
    brush           = rectangle(axes_handle,'Curvature', [1 1],'EdgeColor', [1 1 0],'LineWidth',2,'LineStyle','-');
    animatedLine    = animatedline('LineWidth', 1, 'Color', 'blue');
    cmbAction_assign(actionType);

    scroll(frame, 'both');
    uiwait;
    
    function btnToggleValid_clicked(src,event) %#ok, unused arguments 
        if numel(SelObjID) > 1
            disp('multple objects selected');
            % Multiple objects selected
            
            for i = 1: numel(SelObjID)
                passI(SelObjID(i)) = ~passI(SelObjID(i));
            end            
            SelObjID = 0;            % Clear selection
            PosZoom  = [-1, -1, -1]; % Clear selection
            scroll(frame, 'right');
            
        elseif SelObjID > 0
            % Only one object selected
            
            passI(SelObjID) = ~passI(SelObjID);
            set(txtValidObjs,'string',['Valid: ' num2str(numel(find(passI)))]);
            SelObjID = 0;            % Clear selection
            PosZoom  = [-1, -1, -1]; % Clear selection
            scroll(frame, 'right');
        end
    end

    function cmbAction_changed(src,event) %#ok, unused parameters
        switch get(src,'Value')
            case 1, actionType = 'Select';                
        end
    end

    function cmbAction_assign(newType)
        switch newType
            case 'Select',      set(cmbAction, 'Value', 1);
        end
    end

    function cmbFilterDir_changed(src,event) %#ok, unused arguments
        applyFilter(thresh, thresh2);
    end

    function chkShowObjects_changed(src,event) %#ok, unused arguments
        scroll(frame, 'right');
    end

    function btnZoomOut_clicked(src, event) %#ok, unused arguments        
        % Ensure new zoomed region is still within image borders
        CutNumVox = [min(CutNumVox(1)*2, size(Post,1)), min(CutNumVox(2)*2, size(Post, 2))];
        Pos       = [min(Pos(1),size(ImStk,2)-CutNumVox(2)/2), min(Pos(2),size(ImStk,1)-CutNumVox(1)/2), frame];       
        PosRect   = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];
        PosZoom   = [-1, -1, -1];
        scroll(frame, 'both');
    end

    function btnZoomIn_clicked(src, event) %#ok, unused arguments
        CutNumVox = [max(round(CutNumVox(1)/2,0), 32), max(round(CutNumVox(2)/2,0),32)];
        PosRect   = [max(1,Pos(1)-CutNumVox(2)/2), max(1,Pos(2)-CutNumVox(1)/2)];        
        PosZoom   = [-1, -1, -1];
        scroll(frame, 'both');
    end

    function btnSave_clicked(src, event) %#ok, unused arguments
        Filter.passF    = passI;
        save([pwd filesep 'Filter.mat'], 'Filter');
        msgbox('Validated objects saved.', 'Saved', 'help');
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
                Filter.FilterOpts.Thresholds.ITMaxDir = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds.ITMax    = new_thresh2;
            case 3 % Volume
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.Vol >= new_thresh2)';
                else
                    passI = passI & (Dots.Vol <= new_thresh2)';
                end
                Filter.FilterOpts.Thresholds.VolDir = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds.Vol    = new_thresh2;
            case 4 % Brighness
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.MeanBright >= new_thresh2)';
                else    
                    passI = passI & (Dots.MeanBright <= new_thresh2)';
                end
                Filter.FilterOpts.Thresholds.MeanBrightDir  = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds.MeanBright     = new_thresh2;
            case 5 % Oblongness
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.Shape.Oblong >= new_thresh2)';
                else    
                    passI = passI & (Dots.Shape.Oblong <= new_thresh2)';
                end
                Filter.FilterOpts.Thresholds.OblongDir  = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds.Oblong     = new_thresh2;
            case 6 % Principal axis length
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.Shape.PrincipalAxisLen(:,1)' >= new_thresh2)';
                else    
                    passI = passI & (Dots.Shape.PrincipalAxisLen(:,1)' <= new_thresh2)';
                end
                Filter.FilterOpts.Thresholds.PrincipalAxisLenDir  = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds.PrincipalAxisLen     = new_thresh2;
            case 7 % Z position
                if cmbFilter2Dir.Value == 1
                    passI = passI & (Dots.Pos(:,3) >= new_thresh2);
                else    
                    passI = passI & (Dots.Pos(:,3) <= new_thresh2);
                end
                Filter.FilterOpts.Thresholds.Zposition  = cmbFilter2Dir.Value;
                Filter.FilterOpts.Thresholds.Zposition  = new_thresh2;                
        end      
        
        set(txtValidObjs,'string',['Valid Objects: ' num2str(numel(find(passI)))]);
        scroll(frame, 'right');
    end

    function selectDotsWithinPolyArea(xv, yv)
        % Find indeces of Dots with voxels within passed polygon area
        % xv,yv: coordinates of the polygon vertices
        
        % Switch mouse pointer to hourglass while computing
        oldPointer = get(fig_handle, 'Pointer');
        set(fig_handle, 'Pointer', 'watch'); pause(0.3);

        if numel(xv) == 0 || numel(yv) == 0
            % If user clicked without drawing polygon, query that position
            set(fig_handle, 'Units', 'pixels');
            click_point = get(gca, 'CurrentPoint');
            
            PosX     = ceil(click_point(1,1));
            PosZoomX = PosX - size(ImStk,2)+1;
            PosZoomX = ceil(PosZoomX * CutNumVox(2)/size(ImStk,2));

            PosY     = ceil(click_point(1,2));                        
            PosZoomY = size(ImStk,1) - PosY;
            PosZoomY = ceil(CutNumVox(1)-PosZoomY*CutNumVox(1)/size(ImStk,1));

            PosZoom  = [PosZoomX, PosZoomY frame];
            Pos      = [Pos(1), Pos(2) frame];
            SelObjID = 0;
        else        
            % Create mask inside the passed polygon coordinates
            [x, y] = meshgrid(1:size(ImStk,2), 1:size(ImStk,1));
            mask   = inpolygon_fast(x,y,xv,yv); % ~75x faster than inpolygon
            
            % Select Dot IDs id their voxels fall within the polygon arel
            SelObjID = [];
            for i = 1:numel(Dots.Vox)
                for j = 1:size(Dots.Vox(i).Pos,1)
                    if Dots.Vox(i).Pos(j, 3) == frame
                        ind = sub2ind(size(mask), Dots.Vox(i).Pos(j,1), Dots.Vox(i).Pos(j,2));
                        if mask(ind) && isempty(SelObjID)
                            SelObjID = i;
                            break
                        elseif mask(ind) && ~isempty(SelObjID)
                            SelObjID(end+1) = i; %#ok
                            break
                        end
                    end
                end
            end
        end
        
        % Switch back mouse pointer to the original shape
        set(fig_handle, 'Pointer', oldPointer);
    end

    function wheel_scroll(src, event) %#ok, unused arguments
          if event.VerticalScrollCount < 0              
              %position = get(scroll_handle, 'XData');
              %disp(position);
              scroll(frame+1, 'both'); % Scroll up
          elseif event.VerticalScrollCount > 0             
              scroll(frame-1, 'both'); % Scroll down
          end
    end
    
    function key_press(src, event) %#ok, unused arguments
        %event.Key % displays the name of the pressed key
        switch event.Key  % Process shortcut keys
            case 'space'
                chkShowObjects.Value = ~chkShowObjects.Value;
                chkShowObjects_changed();
            case 'v'
                btnToggleValid_clicked();
            case {'leftarrow','a'}
                Pos = [max(CutNumVox(2)/2, Pos(1)-CutNumVox(1)+ceil(CutNumVox(2)/5)), Pos(2),frame];
                PosZoom = [-1, -1, -1];
                scroll(frame, 'both');
            case {'rightarrow','d'}
                Pos = [min(size(ImStk,2)-1-CutNumVox(2)/2, Pos(1)+CutNumVox(2)-ceil(CutNumVox(2)/5)), Pos(2),frame];
                PosZoom = [-1, -1, -1];
                scroll(frame, 'both');
            case {'uparrow','w'}
                Pos = [Pos(1), max(CutNumVox(1)/2, Pos(2)-CutNumVox(1)+ceil(CutNumVox(1)/5)),frame];
                PosZoom = [-1, -1, -1];
                scroll(frame,'both');
            case {'downarrow','s'}
                Pos = [Pos(1), min(size(ImStk,1)-1-CutNumVox(1)/2, Pos(2)+CutNumVox(1)-ceil(CutNumVox(1)/5)),frame];
                PosZoom = [-1, -1, -1];
                scroll(frame, 'both');
            case 'equal' , btnZoomIn_clicked;
            case 'hyphen', btnZoomOut_clicked;
        end
    end

	%mouse handler
	function button_down(src, event)
		set(src,'Units','norm')
		click_pos = get(src, 'CurrentPoint');
        if click_pos(2) <= 0.035
            click = 1; % click happened on the scroll bar
            on_click(src,event);
        else
            click = 2; % click happened somewhere else
            on_click(src,event);
        end
	end

	function button_up(src, event)  %#ok, unused arguments
		click = 0;
        click_point = get(gca, 'CurrentPoint');
        MousePosX   = ceil(click_point(1,1));
        switch actionType
            case {'Select'}
                if MousePosX > size(ImStk,2)
                    [x,y] = getpoints(animatedLine);

                    % Locate position of points in respect to zoom area
                    PosZoomX = x - size(ImStk,2)-1;
                    PosZoomX = round(PosZoomX * CutNumVox(2)/(size(ImStk,2)-1));                
                    PosZoomY = size(ImStk,1) - y;
                    PosZoomY = CutNumVox(1)-round(PosZoomY*CutNumVox(1)/(size(ImStk,1)-1));

                    % Locate position of points in respect to original img
                    absX = PosZoomX + PosRect(1);
                    absY = PosZoomY + PosRect(2);

                    % Fill every point within delimited perimeter
                    selectDotsWithinPolyArea(absX, absY);
                    delete(animatedLine);
                end
        end
        scroll(frame, 'right');
	end

	function on_click(src, event)  %#ok, unused arguments
        switch click
            case 0 % Moved mouse without clickling
                % Set the proper mouse pointer appearance
                set(fig_handle, 'Units', 'pixels');
                click_point = get(gca, 'CurrentPoint');
                PosX = ceil(click_point(1,1));
                PosY = ceil(click_point(1,2));

                if PosY < 0 || PosY > size(ImStk,1)
                    % Display the default arrow everywhere else
                    set(fig_handle, 'Pointer', 'arrow');
                    return;
                end

                if exist('oldPointer', 'var') && strcmp(oldPointer, 'watch')
                    return;
                elseif PosX <= size(ImStk,2)
                    % Mouse in Left Panel, display a hand
                    set(fig_handle, 'Pointer', 'fleur');
                elseif PosX <= size(ImStk,2)*2
                    % Mouse in Right Panel, act depending of the selected tool
                    [PCData, PHotSpot] = getPointerCrosshair;
                    set(fig_handle, 'Pointer', 'custom', 'PointerShapeCData', PCData, 'PointerShapeHotSpot', PHotSpot);
                else
                    % Display the default arrow everywhere else
                    set(fig_handle, 'Pointer', 'arrow');
                end
            case 1 % Clicked on the scroll bar, move to new frame                
                set(fig_handle, 'Units', 'normalized');
                click_point = get(fig_handle, 'CurrentPoint');
                set(fig_handle, 'Units', 'pixels');
                x = click_point(1) / 0.9; % scroll bar size = 0.9 of window
                
                % get corresponding frame number
                new_f = floor(1 + x * nFrames);
                
                if new_f < 1 || new_f > nFrames || new_f == frame
                    return
                end
                scroll(new_f, 'both');
                
            case 2  % User clicked on image
                set(fig_handle, 'Units', 'pixels');
                click_point = get(gca, 'CurrentPoint');
                PosX = ceil(click_point(1,1));
                PosY = ceil(click_point(1,2));
                
                if PosX <= size(ImStk,2) % User clicked on LEFT-panel
                    ClickPos = [max(CutNumVox(2)/2+1, PosX),...
                                max(CutNumVox(1)/2+1, PosY)];
                    
                    % Make sure zoom rectangle is within image area
                    Pos = [max(CutNumVox(2)/2, PosX),...
                           max(CutNumVox(1)/2, PosY), frame];
                    
                    Pos = [min(size(ImStk,2)-CutNumVox(2)/2,ClickPos(1)),...
                           min(size(ImStk,1)-CutNumVox(1)/2,ClickPos(2)), frame];
                    PosZoom  = [-1, -1, -1];
                    PosRect  = [ClickPos(1)-CutNumVox(2)/2, ClickPos(2)-CutNumVox(1)/2];
                    scroll(frame, 'left');
                    
                else % User clicked in the RIGHT-panel (zoomed region)                    
                    % Detect coordinates of the point clicked in PosZoom
                    % Note: x,y coordinates are inverted in ImStk
                    % Note: x,y coordinates are inverted in CutNumVox

                    PosZoomX = PosX - size(ImStk,2)-1;
                    PosZoomX = round(PosZoomX * CutNumVox(2)/(size(ImStk,2)-1));
                    
                    PosZoomY = size(ImStk,1) - PosY;
                    PosZoomY = CutNumVox(1)-round(PosZoomY*CutNumVox(1)/(size(ImStk,1)-1));

                    % Do different things depending whether left/right-clicked
                    clickType = get(fig_handle, 'SelectionType');
                    
                    if strcmp(clickType, 'alt')
                        % User RIGHT-clicked in the right panel (zoomed region)
                        % Move the view to that position
                        
                        PosZoom = [-1, -1, -1];
                        Pos     = [Pos(1)+PosZoomX-CutNumVox(2)/2,...
                                   Pos(2)+PosZoomY-CutNumVox(1)/2, frame];
                        
                        % Make sure zoom rectangle is within image area
                        Pos = [max(CutNumVox(2)/2+1,Pos(1)),...
                               max(CutNumVox(1)/2+1,Pos(2)), frame];
                        Pos = [min(size(ImStk,2)-CutNumVox(2)/2,Pos(1)),...
                               min(size(ImStk,1)-CutNumVox(1)/2,Pos(2)),frame];
                        
                    elseif strcmp(clickType, 'normal')
                        % User LEFT-clicked in the right panel (zoomed region)
                        
                        PosZoom = [PosZoomX, PosZoomY frame];
                        Pos     = [Pos(1), Pos(2) frame];
                        
                        % Absolute position on image of point clicked on right panel
                        % position Pos. Note: Pos(2) is X, Pos(1) is Y
                        fymin = max(ceil(Pos(2) - CutNumVox(1)/2), 1);
                        fymax = min(ceil(Pos(2) + CutNumVox(1)/2), size(ImStk,1));
                        fxmin = max(ceil(Pos(1) - CutNumVox(2)/2), 1);
                        fxmax = min(ceil(Pos(1) + CutNumVox(2)/2), size(ImStk,2));
                        fxpad = CutNumVox(1) - (fxmax - fxmin); % add padding if position of selected rectangle fall out of image
                        fypad = CutNumVox(2) - (fymax - fymin); % add padding if position of selected rectangle fall out of image
                        absX  = fxpad+fxmin+PosZoom(1);
                        absY  = fypad+fymin+PosZoom(2);
                        
                        if absX>0 && absX<=size(ImStk,2) && absY>0 && absY<=size(ImStk,1)
                            switch actionType
                                case 'Select'                                    
                                    % Set mouse pointer shape to a crosshair
                                    [PCData, PHotSpot] = getPointerCrosshair;
                                    set(fig_handle, 'Pointer', 'custom', 'PointerShapeCData', PCData, 'PointerShapeHotSpot', PHotSpot);
                                    if isvalid(brush), delete(brush); end
                                    
                                    % Add selected pixels to Dot #ID
                                    if ~isvalid(animatedLine)
                                        animatedLine = animatedline('LineWidth', 1, 'Color', 'blue');
                                    else
                                        addpoints(animatedLine, PosX, PosY);
                                    end                                    
                                    return
                            end
                        end
                    end
                    scroll(frame, 'right');
                end
        end
	end

	function scroll(new_f, WhichPanel)
        if new_f < 1 || new_f > nFrames
            return
        end
        
    	% Move scroll bar to new position
        frame = new_f;
        scroll_x = (frame - 1) / nFrames;
        set(scroll_handle, 'XData', scroll_x + [0 1 1 0] * scroll_bar_width);
        
        %set to the right axes and call the custom redraw function
        set(fig_handle, 'CurrentAxes', axes_handle);
        set(fig_handle,'DoubleBuffer','off');
        switch WhichPanel
            case 'both',  [SelObjID, frame_handle, rect_handle] = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, ImStk, CutNumVox, Dots, passI, SelObjID, 'both');
            case 'left',  [SelObjID, frame_handle, rect_handle] = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, ImStk, CutNumVox, Dots, passI, SelObjID, 'left');                
            case 'right', [SelObjID, frame_handle, rect_handle] = redraw(frame_handle, rect_handle, frame, chkShowObjects.Value, Pos, PosZoom, ImStk, CutNumVox, Dots, passI, SelObjID, 'right');                
        end        
        
        if numel(SelObjID) == 1 && SelObjID > 0
            set(txtSelObjID     ,'string',['ID#: '          num2str(SelObjID)]);
            set(txtSelObjITMax  ,'string',['Score : '       num2str(Dots.ITMax(SelObjID))]);
            set(txtSelObjVol    ,'string',['Volume : '      num2str(Dots.Vol(SelObjID))]);
            set(txtSelObjBright ,'string',['Brightness : '  num2str(ceil(Dots.MeanBright(SelObjID)))]);
            try
                set(txtSelObjRound  ,'string',['Roundness : '   num2str(Dots.Shape.Oblong(SelObjID))]);
                set(txtSelObjLength ,'string',['Length : '      num2str(ceil(Dots.Shape.PrincipalAxisLen(SelObjID)))]);
            catch
                set(txtSelObjRound  ,'string','Roundness : ');
                set(txtSelObjLength ,'string','Length : '   );
            end    
            set(txtSelObjValid  ,'string',['Validated : '   num2str(ceil(passI(SelObjID)))]);
            
        else
            set(txtSelObjID     ,'string','ID#: '       );
            set(txtSelObjITMax  ,'string','Score : '    );
            set(txtSelObjVol    ,'string','Volume : '   );
            set(txtSelObjBright ,'string','Brightness :');
            set(txtSelObjRound  ,'string','Roundness : ');
            set(txtSelObjLength ,'string','Length : '   );
            set(txtSelObjValid  ,'string','Validated : ');
        end
    end
end

function [SelObjID, image_handle, navi_handle] = redraw(image_handle, navi_handle, frameNum, ShowObjects, Pos, PosZoom, Post, NaviRectSize, Dots, Filter, SelectedObjIDs, WhichPanel)
%% Redraw function, full image on left panel, zoomed area on right panel
% Note: Pos(1), PosZoom(1), Post(1), PostCut(1), NaviRectSize(1) = Y
% Note: Dots.Pos(:,1) = X

SelObjID        = 0;
SelObjColor     = uint8([1 1 0])'; % Yellow
ValObjColor     = uint8([0 1 0])'; % Green
RejObjColor     = uint8([1 0 0])'; % Gray

F               = squeeze(Post(:,:,frameNum,:));
PostCut         = zeros(NaviRectSize(1), NaviRectSize(2), 3, 'uint8');
PostCutResized  = zeros(size(Post,1), size(Post,2), 3, 'uint8');
PostVoxMapCut   = PostCut;

if (Pos(1) > 0) && (Pos(2) > 0) && (Pos(1) < size(Post,2)) && (Pos(2) < size(Post,1))
    % Find borders of the area to zoom according to passed mouse position
    % Pos(2), NaviRectSize(2) is X      
    fxmin = max(ceil(Pos(2) - NaviRectSize(2)/2)+1, 1);
    fxmax = min(ceil(Pos(2) + NaviRectSize(2)/2), size(Post,2));
    fxpad = NaviRectSize(2) - (fxmax - fxmin); % padding if out of image

    fymin = max(ceil(Pos(1) - NaviRectSize(1)/2)+1, 1);
    fymax = min(ceil(Pos(1) + NaviRectSize(1)/2), size(Post,1));
    fypad = NaviRectSize(1) - (fymax - fymin); % padding if out of image
    
    % Find indeces of valid and rejected objects within the zoomed area
    valIcut = Filter;
    rejIcut = ~Filter;
    for i = 1:numel(valIcut)
        valIcut(i) = valIcut(i) && Dots.Pos(i,1)>fxmin && Dots.Pos(i,1)<fxmax && Dots.Pos(i,2)>fymin && Dots.Pos(i,2)<fymax;
        rejIcut(i) = rejIcut(i) && Dots.Pos(i,1)>fxmin && Dots.Pos(i,1)<fxmax && Dots.Pos(i,2)>fymin && Dots.Pos(i,2)<fymax;
    end
    VisObjIDs = find(valIcut);  
    RejObjIDs = find(rejIcut);

    % Flag valid and rejected object IDs within zoomed area    
    for i=1:numel(VisObjIDs)
        VoxPos = Dots.Vox(VisObjIDs(i)).Pos;
        for j = 1:size(VoxPos,1)
            if VoxPos(j,3) == frameNum && VoxPos(j,1)>fxmin && VoxPos(j,1)<fxmax && VoxPos(j,2)>fymin && VoxPos(j,2)<fymax
                PostVoxMapCut(VoxPos(j,1)+fxpad-fxmin+1,VoxPos(j,2)+fypad-fymin+1, :) = ValObjColor;
            end
        end
    end
    for i=1:numel(RejObjIDs)
        VoxPos = Dots.Vox(RejObjIDs(i)).Pos;
        for j = 1:size(VoxPos,1)
            if VoxPos(j,3) == frameNum && VoxPos(j,1)>fxmin && VoxPos(j,1)<fxmax && VoxPos(j,2)>fymin && VoxPos(j,2)<fymax
                PostVoxMapCut(VoxPos(j,1)+fxpad-fxmin+1,VoxPos(j,2)+fypad-fymin+1,:) = RejObjColor;
            end
        end
    end
    
    if ~isempty(SelectedObjIDs) && (numel(SelectedObjIDs)>1 || SelectedObjIDs > 0)
        % If user requested objects within the zoomed region, select them
        
        SelObjID = SelectedObjIDs;        
        for i = 1: numel(SelectedObjIDs)
            VoxPos = Dots.Vox(SelectedObjIDs(i)).Pos;
            %disp(['SelectedObjID: ' num2str(SelectedObjIDs(i))]);
            for j = 1:size(VoxPos,1)
                if VoxPos(j,1)>fxmin && VoxPos(j,1)<fxmax && VoxPos(j,2)>fymin && VoxPos(j,2)<fymax            
                    PostVoxMapCut(VoxPos(j,1)+fxpad-fxmin+1,VoxPos(j,2)+fypad-fymin+1, :) = SelObjColor;
                end
            end
        end
    elseif PosZoom(1) > 0 && PosZoom(2) > 0
        % If user queried for objects at a specific location coordinates
        %disp(['X:' num2str(PosZoom(1)) ' Y:' num2str(PosZoom(2)) ' xmin:' num2str(fxmin) ' ymin:' num2str(fymin)]);
        absX = fxpad+fxmin+PosZoom(2)-1;            
        absY = fypad+fymin+PosZoom(1)-2;
        for i=1:numel(VisObjIDs)
            VoxPos  = Dots.Vox(VisObjIDs(i)).Pos;
            for j = 1:size(VoxPos,1)                
                if VoxPos(j,3)==frameNum && VoxPos(j,1)==absX && VoxPos(j,2)==absY
                    SelObjID = VisObjIDs(i); % Return ID of selected object
                    for k = 1:size(VoxPos,1)
                        if VoxPos(k,3) == frameNum
                            PostVoxMapCut(VoxPos(k,1)+fxpad-fxmin+1, VoxPos(k,2)+fypad-fymin+1, :) = SelObjColor;
                        end
                    end
                    break
                end
            end
        end
        
        if SelObjID == 0
            % Clicked positon does not belong to any validated object,
            % check if belong to any of the rejected objects intead
            
            for i=1:numel(RejObjIDs)
                VoxPos = Dots.Vox(RejObjIDs(i)).Pos;
                for j = 1:size(VoxPos,1)
                    if VoxPos(j,3) == frameNum  && VoxPos(j,1)==absX && VoxPos(j,2)==absY
                        SelObjID = RejObjIDs(i);
                        for k = 1:size(VoxPos,1)
                            if VoxPos(k,3) == frameNum
                                PostVoxMapCut(VoxPos(k,1)+fxpad-fxmin+1,VoxPos(k,2)+fypad-fymin+1, :) = SelObjColor;
                            end
                        end
                        break
                    end
                end
            end
        end
        
    end
    
    % Draw the right panel containing a zoomed version of selected area
    PostCut(fxpad+1 : fxpad+fxmax-fxmin, fypad+1 : fypad+fymax-fymin,:) = F(fxmin:fxmax-1, fymin:fymax-1, :);
    if ShowObjects
        PostCutResized = imresize(PostCut.*PostVoxMapCut,[size(Post,1), size(Post,2)], 'nearest');
    else
        PostCutResized = imresize(PostCut,[size(Post,1), size(Post,2)], 'nearest');        
    end
    
    % Separate left and right panel visually with a vertical line
    PostCutResized(1:end, 1:4, 1:3) = 75;
end

if image_handle == 0
    % Draw the full image if it is the first time
    image_handle = image(cat(2, F, PostCutResized));
    axis image off
    % Draw a rectangle border over the selected area (left panel)
    navi_handle = rectangle(gca, 'Position',[fymin,fxmin,NaviRectSize(2),NaviRectSize(1)],'EdgeColor', [1 1 0],'LineWidth',2,'LineStyle','-');
else
    % If we already drawn the image once, just update WhichPanel is needed
    switch  WhichPanel       
        case 'both'
            CData = get(image_handle, 'CData');
            CData(:, 1:size(CData,2)/2,:) = F; % redraw left panel
            CData(:, size(CData,2)/2+1:size(CData,2),:) = PostCutResized; % redraw right panel
            set(image_handle, 'CData', CData);   
            set(navi_handle, 'Position',[fymin,fxmin,NaviRectSize(2),NaviRectSize(1)]);
        case 'left'            
            set(navi_handle, 'Position',[fymin,fxmin,NaviRectSize(2),NaviRectSize(1)]);
        case 'right'
            CData = get(image_handle, 'CData');
            CData(:, size(CData,2)/2+1:size(CData,2),:) = PostCutResized;
            set(image_handle, 'CData', CData);   
    end
end
end

function [ShapeCData, HotSpot] = getPointerCrosshair
    %% Custom mouse crosshair pointer sensitive at arms intersection point 
    ShapeCData          = zeros(32,32);
    ShapeCData(:,:)     = NaN;
    ShapeCData(15:17,:) = 1;
    ShapeCData(:, 15:17)= 1;
    ShapeCData(16,:)    = 2;
    ShapeCData(:, 16)   = 2;
    HotSpot             = [16,16];
end