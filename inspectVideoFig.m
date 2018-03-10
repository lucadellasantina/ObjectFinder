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
%VIDEOFIG Figure with horizontal scrollbar and play capabilities.
%   VIDEOFIG(NUM_FRAMES, @REDRAW_FUNC)
%   Creates a figure with a horizontal scrollbar and shortcuts to scroll
%   automatically. The scroll range is 1 to NUM_FRAMES. The function
%   REDRAW_FUNC(F) is called to redraw at scroll position F (for example,
%   REDRAW_FUNC can show the frame F of a video).
%   This can be used not only to play and analyze standard videos, but it
%   also lets you place any custom Matlab plots and graphics on top.
%
%   The keyboard shortcuts are:
%     Enter (Return) -- play/pause video (25 frames-per-second default).
%     Backspace -- play/pause video 5 times slower.
%     Right/left arrow keys -- advance/go back one frame.
%     Page down/page up -- advance/go back 30 frames.
%     Home/end -- go to first/last frame of video.
%
%   Advanced usage
%   --------------
%   VIDEOFIG(NUM_FRAMES, @REDRAW_FUNC, FPS, BIG_SCROLL)
%   Also specifies the speed of the play function (frames-per-second) and
%   the frame step of page up/page down (or empty for defaults).
%
%   VIDEOFIG(NUM_FRAMES, @REDRAW_FUNC, FPS, BIG_SCROLL, @KEY_FUNC)
%   Also calls KEY_FUNC(KEY) with any keys that weren't processed, so you
%   can add more shortcut keys (or empty for none).
%
%   VIDEOFIG(NUM_FRAMES, @REDRAW_FUNC, FPS, BIG_SCROLL, @KEY_FUNC, ...)
%   Passes any additional arguments to the native FIGURE function (for
%   example: 'Name', 'Video figure title').
%
%   [FIG_HANDLE, AX_HANDLE, OTHER_HANDLES, SCROLL] = VIDEOFIG(...)
%   Returns the handles of the figure, drawing axes and other handles (of
%   the scrollbar's graphics), respectively. SCROLL(F) can be called to
%   scroll to frame F, or with no arguments to just redraw the figure.
%
%   Example 1
%   ---------
%   Place this in a file called "redraw.m":
%     function redraw(frame)
%         imshow(['AT3_1m4_' num2str(frame, '%02.0f') '.tif'])
%     end
%
%   Then from a script or the command line, call:
%     videofig(10, @redraw);
%     redraw(1)
%
%   The images "AT3_1m4_01.tif" ... "AT3_1m4_10.tif" are part of the Image
%   Processing Toolbox and there's no need to download them elsewhere.
%
%   Example 2
%   ---------
%   Change the redraw function to visualize the contour of a single cell:
%     function redraw(frame)
%         im = imread(['AT3_1m4_' num2str(frame, '%02.0f') '.tif']);
%         slice = im(210:310, 210:340);
%         [ys, xs] = find(slice < 50 | slice > 100);
%         pos = 210 + median([xs, ys]);
%         siz = 3.5 * std([xs, ys]);
%         imshow(im), hold on
%         rectangle('Position',[pos - siz/2, siz], 'EdgeColor','g', 'Curvature',[1, 1])
%         hold off
%     end
%
%   João Filipe Henriques, 2010
%
function [fig_handle, axes_handle, scroll_bar_handles, scroll_func] = ...
	inspectVideoFig(num_frames, redraw_func, big_scroll, key_func, ImStk, Dots, Filter, varargin)

	% Default parameter values
	if nargin < 3 || isempty(big_scroll), big_scroll = 30; end  %page-up and page-down advance, in frames
	if nargin < 4, key_func = []; end
    
	% Check arguments
	check_int_scalar(num_frames);
	check_callback(redraw_func);
	check_int_scalar(big_scroll);
	check_callback(key_func);

    size_video = [0 0 0.90 1];
	click = 0;      % Initialize click status
    f = ceil(num_frames/2); % Current frame
    %Pos = [1,1,0];  % Initial position of interest
    Pos = [ceil(size(ImStk,1)/2), ceil(size(ImStk,2)/2), ceil(size(ImStk,3)/2)];
    passI = Filter.passF;
    thresh = ceil(mean(Dots.ITMax));
    thresh2 = 0;
	
	% Initialize figure
	fig_handle = figure('Color',[.3 .3 .3], 'MenuBar','none', 'Units','norm', ...
		'WindowButtonDownFcn',@button_down, 'WindowButtonUpFcn',@button_up, ...
		'WindowButtonMotionFcn', @on_click, 'KeyPressFcn', @key_press,...
        'windowscrollWheelFcn', @wheel_scroll, varargin{:});
	
	% Axes for scroll bar
	scroll_axes_handle = axes('Parent',fig_handle, 'Position',[0 0 1 0.035], ...
		'Visible','off', 'Units', 'normalized');
	axis([0 1 0 1]);
	axis off
	
	% Scroll bar
	scroll_bar_width = max(1 / num_frames, 0.01);
	scroll_handle = patch([0 1 1 0] * scroll_bar_width, [0 0 1 1], [.8 .8 .8], ...
		'Parent',scroll_axes_handle, 'EdgeColor','none', 'ButtonDownFcn', @on_click);

    % User interface conmponents
    set(gcf,'units', 'normalized', 'position', [0.05 0.1 0.9 0.76]);
    uicontrol('Style','text','Units','normalized','position',[.08,.035,.28,.02],'String','Image navigator, use scroll wheel to move along Z, click to zoom a region of interest');
    uicontrol('Style','text','Units','normalized','position',[.52,.035,.28,.02],'String','Zoomed region, green = raw signal, magenta = objects passing current threshold');

    txtValidObjs_handle = uicontrol('Style','text','Units','normalized','position',[.91,.93,.08,.02],'String',['Valid Objects: ' num2str(numel(find(passI)))]);
    txtTotalObjs_handle = uicontrol('Style','text','Units','normalized','position',[.91,.90,.08,.02],'String',['Total Objects: ' num2str(numel(Dots.Vox))]);
    
    % Primary filter parameter controls
    uicontrol('Style','text','Units','normalized','position',[.91,.84,.08,.02],'String','Primary filter parameter');    
    cmbFilterType_handle = uicontrol('Style', 'popup', 'Units','normalized', ...
            'String', {'ITMax','Volume','Brightness'}, 'Position', [.907,.79,.085,.04],...
            'Callback', @cmbFilterType_changed);    
    btnMinus_handle = uicontrol('Style','Pushbutton','Units','normalized','position',[.91,.75,.02,.04],...
        'String','-','CallBack',@btnMinus_clicked);    
    txtThresh_handle = uicontrol('Style','edit','Units','normalized','Position',[.93 .75 .036 .04],... 
             'CallBack',@txtThresh_changed,'String',num2str(thresh));
    btnPlus_handle = uicontrol('Style','Pushbutton','Units','normalized','position',[.967,.75,.02,.04],...
        'String','+','CallBack',@btnPlus_clicked);    

    % Secondary filter parameter controls
    uicontrol('Style','text','Units','normalized','position',[.91,.68,.08,.02],'String','Secondary filter parameter');    
    cmbFilterType2_handle = uicontrol('Style', 'popup', 'Units','normalized', ...
            'String', {'None','ITMax','Volume','Brightness'}, 'Position', [.907,.63,.085,.04],...
            'Callback', @cmbFilterType2_changed);    
    btnMinus2_handle = uicontrol('Style','Pushbutton','Units','normalized','position',[.91,.59,.02,.04],...
        'String','-','Visible','off','CallBack',@btnMinus2_clicked);    
    txtThresh2_handle = uicontrol('Style','edit','Units','normalized','Position',[.93 .59 .036 .04],... 
        'Visible','off','CallBack',@txtThresh2_changed,'String',num2str(thresh2));
    btnPlus2_handle = uicontrol('Style','Pushbutton','Units','normalized','position',[.967,.59,.02,.04],...
        'String','+','Visible','off','CallBack',@btnPlus2_clicked);    
    
    
    uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.13,.085,.05],...
        'String','Save','Callback',@btnSave_clicked);    
    uicontrol('Style','Pushbutton','Units','normalized','position',[.907,.07,.085,.05],...
        'String','Close','Callback','close');

    
	% Timer to play video
	play_timer = timer('TimerFcn',@play_timer_callback, 'ExecutionMode','fixedRate');
	
	% Main drawing axes for video display
    if size_video(2) < 0.03; size_video(2) = 0.03; end; %bottom 0.03 must be used for scroll bar HO 2/17/2011
	axes_handle = axes('Position',size_video); %[0 0.03 1 0.97] to size_video (6th input argument) to allow space for buttons and annotations 2/13/2011 HO
	
	% Return handles
	scroll_bar_handles = [scroll_axes_handle; scroll_handle];
	scroll_func = @scroll;
	scroll(f);
    
    function btnSave_clicked(src, event)
        Filter.passF = passI;
        save([pwd filesep 'Filter.mat'], 'Filter');
    end

    function btnPlus_clicked(src, event)
        new_thresh = thresh + 1;
        set(txtThresh_handle,'string',num2str(new_thresh));
        applyFilter(new_thresh, thresh2);
    end

    function btnMinus_clicked(src, event)
        new_thresh = max(thresh - 1, 0);
        set(txtThresh_handle,'string',num2str(new_thresh));
        applyFilter(new_thresh, thresh2);
    end

    function txtThresh_changed(src, event)
        thresh_str = get(src,'String');
        new_thresh = str2num(thresh_str);
        applyFilter(new_thresh, thresh2);
    end

    function btnPlus2_clicked(src, event)
        new_thresh2 = thresh2 + 1;
        set(txtThresh2_handle,'string',num2str(new_thresh2));
        applyFilter(thresh, new_thresh2);
    end

    function btnMinus2_clicked(src, event)
        new_thresh2 = max(thresh2 - 1, 0);
        set(txtThresh2_handle,'string',num2str(new_thresh2));
        applyFilter(thresh, new_thresh2);
    end

    function txtThresh2_changed(src, event)
        thresh_str = get(src,'String');
        new_thresh2 = str2num(thresh_str);
        applyFilter(thresh, new_thresh2);
    end

    function cmbFilterType_changed(src, event)
        switch get(src,'Value')
            case 1 % ITMax
                new_thresh = ceil(mean(Dots.ITMax));
            case 2 % Volume
                new_thresh = ceil(mean(Dots.Vol));
            case 3 % Brightness
                new_thresh = ceil(mean(Dots.MeanBright));
        end
        set(txtThresh_handle,'string',num2str(new_thresh));
        applyFilter(new_thresh, thresh2);
    end

    function cmbFilterType2_changed(src, event)
        switch get(src,'Value')
            case 1 % None
                new_thresh2 = 0;
                set(txtThresh2_handle,'Visible','off');
                set(btnPlus2_handle,'Visible','off');
                set(btnMinus2_handle,'Visible','off');
            case 2 % ITMax
                new_thresh2 = ceil(mean(Dots.ITMax));
                set(txtThresh2_handle,'Visible','on');
                set(btnPlus2_handle,'Visible','on');
                set(btnMinus2_handle,'Visible','on');                
            case 3 % Volume
                new_thresh2 = ceil(mean(Dots.Vol));
                set(txtThresh2_handle,'Visible','on');
                set(btnPlus2_handle,'Visible','on');
                set(btnMinus2_handle,'Visible','on');                
            case 4 % Brightness
                new_thresh2 = ceil(mean(Dots.MeanBright));
                set(txtThresh2_handle,'Visible','on');
                set(btnPlus2_handle,'Visible','on');
                set(btnMinus2_handle,'Visible','on');                
        end
        applyFilter(thresh, new_thresh2);
        set(txtThresh2_handle,'string',num2str(new_thresh2));        
    end


    function applyFilter(new_thresh, new_thresh2)
        thresh = new_thresh;
        thresh2 = new_thresh2;
        
        % Apply primary filter criteria if selected        
        switch get(cmbFilterType_handle,'Value')
            case 1
                passI = Filter.passF & (Dots.ITMax >= new_thresh)';
            case 2
                passI = Filter.passF & (Dots.Vol >= new_thresh)';
            case 3
                passI = Filter.passF & (Dots.MeanBright >= new_thresh)'; 
        end
        
        % Apply secondary filter criteria if selected
        switch get(cmbFilterType2_handle,'Value')
            case 2 % ITMax
                passI = passI & (Dots.Vol >= new_thresh2)';
            case 3 % Volume
                passI = passI & (Dots.MeanBright >= new_thresh2)'; 
            case 4 % Brighness
                passI = passI & (Dots.MeanBright >= new_thresh2)';                 
        end      
        
        set(txtValidObjs_handle,'string',['Valid Objects: ' num2str(numel(find(passI)))]);
        scroll(f);
    end
    function wheel_scroll(~, event)
          if event.VerticalScrollCount < 0              
              %position = get(scroll_handle, 'XData');
              %disp(position);
              scroll(f+1); % Scroll up
          elseif event.VerticalScrollCount > 0             
              scroll(f-1); % Scroll down
          end
    end
    
	function key_press(src, event)  %#ok, unused arguments
		switch event.Key  % Process shortcut keys
		case 'leftarrow'
			scroll(f - 1);
		case 'rightarrow'
			scroll(f + 1);
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
	function button_down(src, event)  %#ok, unused arguments
		set(src,'Units','norm')
		click_pos = get(src, 'CurrentPoint');
        if click_pos(2) <= 0.035
            click = 1;
            on_click([],[]);
        else
            click = 2;
            on_click([],[]);
        end
	end

	function button_up(src, event)  %#ok, unused arguments
		click = 0;
	end

	function on_click(src, event)  %#ok, unused arguments
		if click == 0, return; end
		
        if click == 1
            %get x-coordinate of click
            set(fig_handle, 'Units', 'normalized');
            click_point = get(fig_handle, 'CurrentPoint');
            set(fig_handle, 'Units', 'pixels');
            x = click_point(1);
            
            %get corresponding frame number
            new_f = floor(1 + x * num_frames);
            
            if new_f < 1 || new_f > num_frames, return; end  %outside valid range
            
            if new_f ~= f  %don't redraw if the frame is the same (to prevent delays)
                scroll(new_f);
            end
        else
            % Get XY-coordinate of click in pixels
            set(fig_handle, 'Units', 'pixels');
            click_point = get(gca, 'CurrentPoint');
            Pos = [ceil(click_point(1,1:2)),f];
            scroll(f);
        end
	end

	function play(period)
		% Toggle between stoping and starting the "play video" timer
		if strcmp(get(play_timer,'Running'), 'off')
			set(play_timer, 'Period', period);
			start(play_timer);
		else
			stop(play_timer);
		end
	end
	function play_timer_callback(src, event)  %#ok
		% Executed at each timer period, when playing the video
		if f < num_frames
			scroll(f + 1);
		elseif strcmp(get(play_timer,'Running'), 'on')
			stop(play_timer);  %stop the timer if the end is reached
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
		redraw_func(f, Pos, passI);
		
		%used to be "drawnow", but when called rapidly and the CPU is busy
		%it didn't let Matlab process events properly (ie, close figure).
		%pause(0.001)
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

