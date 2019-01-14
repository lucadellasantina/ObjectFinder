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

function [fig_handle, axes_handle, scroll_bar_handles, scroll_func] = ...
	inspectVideoFig(num_frames, redraw_func, big_scroll, key_func, ImStk, Dots, Filter, CutNumVox, varargin)

	% Default parameter values
	if nargin < 3 || isempty(big_scroll), big_scroll = 30; end  %page-up and page-down advance, in frames
	if nargin < 4, key_func = []; end
    
	% Check that arguments match the expected types 
	check_int_scalar(num_frames);
	check_callback(redraw_func);
	check_int_scalar(big_scroll);
	check_callback(key_func);

    size_video = [0 0 0.90 1];
	click   = 0;                        % Initialize click status
    f       = ceil(num_frames/2);       % Current frame
    Pos     = [ceil(size(ImStk,1)/2), ceil(size(ImStk,2)/2), ceil(size(ImStk,3)/2)]; % Initial position is middle of the stack
    PosZoom = [-1, -1, -1];             % Initial position in zoomed area
    passI   = Filter.passF;             % Initialize temporary filter
    thresh  = 0;                        % Initialize thresholds
    thresh2 = 0;                        % Initialize thresholds
    SelObjID= 0;                        % Initialize selected object ID#
	
	% Initialize GUI
	fig_handle = figure('Name','Volume inspector (green: raw signal, magenta: validated object, blue: selected object)','NumberTitle','off','Color',[.3 .3 .3], 'MenuBar','none', 'Units','norm', ...
		'WindowButtonDownFcn',@button_down, 'WindowButtonUpFcn',@button_up, 'WindowButtonMotionFcn', @on_click, 'KeyPressFcn', @key_press,'windowscrollWheelFcn', @wheel_scroll, varargin{:});
	
	% Add custom scroll bar
	scroll_axes = axes('Parent',fig_handle, 'Position',[0 0 0.9 0.045], 'Visible','off', 'Units', 'normalized');
	axis([0 1 0 1]); axis off
	scroll_bar_width = max(1 / num_frames, 0.01);
	scroll_handle = patch([0 1 1 0] * scroll_bar_width, [0 0 1 1], [.8 .8 .8], 'Parent',scroll_axes, 'EdgeColor','none', 'ButtonDownFcn', @on_click);

    % Add GUI conmponents
    set(gcf,'units', 'normalized', 'position', [0.05 0.1 0.90 0.76]);
    pnlSettings     = uipanel(  'Title','Objects'   ,'Units','normalized','Position',[.903,.005,.095,.99]); %#ok, unused variable
    txtValidObjs    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.930,.085,.02],'String',['Valid: ' num2str(numel(find(passI)))]);
    txtTotalObjs    = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.900,.085,.02],'String',['Total: ' num2str(numel(passI))]); %#ok, unused variable
    chkShowObjects  = uicontrol('Style','checkbox'  ,'Units','normalized','position',[.912,.870,.085,.02],'String','Show (spacebar)', 'Value',1     ,'Callback',@chkShowObjects_changed);
    btnSave         = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.010,.088,.05],'String','Save current objects'           ,'Callback',@btnSave_clicked); %#ok, unused variable    
    
    % Primary filter parameter controls
    txtFilter       = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.800,.085,.02],'String','Primary filter type'); %#ok, unused variable   
    cmbFilterType   = uicontrol('Style','popup'     ,'Units','normalized','Position',[.907,.750,.060,.04],'String', {'Disabled', 'Score','Volume','Brightness','Roundness','Major Axis Length'},'Callback', @cmbFilterType_changed);  
    cmbFilterDir    = uicontrol('Style','popup'     ,'Units','normalized','Position',[.970,.750,.025,.04],'String', {'>=', '<='}, 'Visible', 'off'  ,'callback',@cmbFilterDir_changed);            
    btnMinus        = uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.715,.025,.04],'String','-','Visible','off'              ,'CallBack',@btnMinus_clicked);    
    txtThresh       = uicontrol('Style','edit'      ,'Units','normalized','Position',[.932,.715,.036,.04],'String',num2str(thresh),'Visible', 'off' ,'CallBack',@txtThresh_changed);
    btnPlus         = uicontrol('Style','Pushbutton','Units','normalized','position',[.970,.715,.025,.04],'String','+','Visible', 'off'             ,'CallBack',@btnPlus_clicked);    

    % Secondary filter parameter controls
    txtFilter2      = uicontrol('Style','text'      ,'Units','normalized','position',[.907,.680,.085,.02],'String','Secondary filter type'); %#ok, unused variable   
    cmbFilterType2  = uicontrol('Style','popup'     ,'Units','normalized','Position',[.907,.630,.060,.04],'String',{'Disabled','Score','Volume','Brightness','Roundness','Major Axis Length'},'Callback', @cmbFilterType2_changed);
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
    
	% Main drawing axes for video display
    if size_video(2) < 0.03; size_video(2) = 0.03; end % bottom 0.03 will be used for scroll bar HO 2/17/2011
	axes_handle = axes('Position',size_video);
	
	% Return handles
	scroll_bar_handles = [scroll_axes; scroll_handle];
	scroll_func = @scroll;    
	scroll(f);
    uiwait;
    
    function btnToggleValid_clicked(src,event) %#ok, unused arguments 
        if SelObjID
            passI(SelObjID) = ~passI(SelObjID);
            set(txtValidObjs,'string',['Valid: ' num2str(numel(find(passI)))]);
            PosZoom = [-1, -1, -1]; % Deselect object after validatio change
            scroll(f);    
        end
    end

    function cmbFilterDir_changed(src,event) %#ok, unused arguments
        applyFilter(thresh, thresh2);
    end

    function chkShowObjects_changed(src,event) %#ok, unused arguments
        scroll(f);
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
        end      
        
        set(txtValidObjs,'string',['Valid Objects: ' num2str(numel(find(passI)))]);
        scroll(f);
    end

    function wheel_scroll(src, event) %#ok, unused arguments
          if event.VerticalScrollCount < 0              
              %position = get(scroll_handle, 'XData');
              %disp(position);
              scroll(f+1); % Scroll up
          elseif event.VerticalScrollCount > 0             
              scroll(f-1); % Scroll down
          end
    end
    
    function key_press(src, event) %#ok, unused arguments
        switch event.Key  % Process shortcut keys
            case 'space'
                chkShowObjects.Value = ~chkShowObjects.Value;
                chkShowObjects_changed();
            case 'v'
                btnToggleValid_clicked();
            case {'leftarrow','a'}
                Pos = [max(CutNumVox(2)/2, Pos(1)-CutNumVox(1)+ceil(CutNumVox(2)/5)), Pos(2),f];
                PosZoom = [-1, -1, -1];
                scroll(f);
            case {'rightarrow','d'}
                Pos = [min(size(ImStk,2)-1-CutNumVox(2)/2, Pos(1)+CutNumVox(2)-ceil(CutNumVox(2)/5)), Pos(2),f];
                PosZoom = [-1, -1, -1];
                scroll(f);
            case {'uparrow','w'}
                Pos = [Pos(1), max(CutNumVox(1)/2, Pos(2)-CutNumVox(1)+ceil(CutNumVox(1)/5)),f];
                PosZoom = [-1, -1, -1];
                scroll(f);
            case {'downarrow','s'}
                Pos = [Pos(1), min(size(ImStk,1)-1-CutNumVox(1)/2, Pos(2)+CutNumVox(1)-ceil(CutNumVox(1)/5)),f];
                PosZoom = [-1, -1, -1];
                scroll(f);
            case 'pageup'
                if f - big_scroll < 1  %scrolling before frame 1, stop at frame 1
                    scroll(1);
                else
                    scroll(f - big_scroll);
                end
            case 'pagedown'
                if f + big_scroll > num_frames  %scrolling after last frame
                    scroll(num_frames);
                else
                    scroll(f + big_scroll);
                end
            case 'home'
                scroll(1);
            case 'end'
                scroll(num_frames);
            case 'return'
                %play(1/play_fps)
            case 'backspace'
                %play(5/play_fps)
            otherwise
                if ~isempty(key_func)
                    key_func(event.Key);  % call custom key handler
                end
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
	end

	function on_click(src, event)  %#ok, unused arguments
		if click == 0, return; end
		
        if click == 1 
            % User clicked the scroll bar, get x-coordinate of click
            
            set(fig_handle, 'Units', 'normalized');
            click_point = get(fig_handle, 'CurrentPoint');
            set(fig_handle, 'Units', 'pixels');
            x = click_point(1) / 0.9; % scroll bar with is 0.9 of window
            
            % get corresponding frame number
            new_f = floor(1 + x * num_frames);
            
            if new_f < 1 || new_f > num_frames, return; end  %outside valid range
            
            if new_f ~= f  %don't redraw if the frame is the same (to prevent delays)
                scroll(new_f);
            end
        else
            % User clicked on the image get XY-coordinates in pixels
            
            set(fig_handle, 'Units', 'pixels');
            click_point = get(gca, 'CurrentPoint');
            PosX = ceil(click_point(1,1));
            PosY = ceil(click_point(1,2));
            if PosX <= size(ImStk,2)
                % Make sure zoom rectangle is within image area
                ClickPos = [max(CutNumVox(2)/2+1, PosX),...
                            max(CutNumVox(1)/2+1, PosY)];
                    
                ClickPos = [min(size(ImStk,2)-CutNumVox(2)/2,ClickPos(1)),...
                            min(size(ImStk,1)-CutNumVox(1)/2,ClickPos(1))];
                Pos      = [ClickPos, f];
                PosZoom  = [-1, -1, -1];
                scroll(f);
            else
                % User clicked in the right panel (zoomed region)
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
                    % User right-clicked in the right panel (zoomed region)
                    % Move the view to that position
                    PosZoom = [-1, -1, -1];
                    Pos     = [Pos(1)+PosZoomX-CutNumVox(2)/2,...
                               Pos(2)+PosZoomY-CutNumVox(1)/2, f];

                    % Make sure zoom rectangle is within image area
                    Pos     = [max(CutNumVox(2)/2+1,Pos(1)),...
                               max(CutNumVox(1)/2+1,Pos(2)), f];
                    Pos     = [min(size(ImStk,2)-CutNumVox(2)/2,Pos(1)),...
                               min(size(ImStk,1)-CutNumVox(1)/2,Pos(2)),f];

                elseif strcmp(clickType, 'normal')
                    % User left-clicked in the riht panel (zoomed region)
                    % Store the position for selecting objects in there
                    PosZoom = [PosZoomX, PosZoomY, f];
                    Pos     = [Pos(1), Pos(2), f];
                end
                scroll(f);
            end
        end
	end

	function scroll(new_f)
		if nargin == 1  %scroll to another position (new_f)
			if new_f < 1 || new_f > num_frames
				return
			end
			f = new_f;
		end
		
		%convert frame number to appropriate x-coordinate of scroll bar
		scroll_x = (f - 1) / num_frames;
		%move scroll bar to new position
		set(scroll_handle, 'XData', scroll_x + [0 1 1 0] * scroll_bar_width);
		%set to the right axes and call the custom redraw function
		set(fig_handle, 'CurrentAxes', axes_handle);
		SelObjID = redraw_func(f, chkShowObjects.Value, Pos, PosZoom, CutNumVox, passI);
        if SelObjID
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
	
	% Convenience functions for argument checks
	function check_int_scalar(a)
		assert(isnumeric(a) && isscalar(a) && isfinite(a) && a == round(a), ...
			[upper(inputname(1)) ' must be a scalar integer number.']);
    end

	function check_callback(a)
		assert(isempty(a) || isa(a, 'function_handle'), ...
			[upper(inputname(1)) ' must be a valid function handle.'])
	end
    end