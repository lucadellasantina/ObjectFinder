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

function [fig_handle, axes_handle, scroll_bar_handles, scroll_func] = ...
	colocVideoFig(redraw_func, play_fps, big_scroll, key_func,...
    ColocManual, Grouped, Post, Colo, Settings, varargin)
	
	%default parameter values
	if nargin < 2 || isempty(play_fps), play_fps = 25; end  %play speed (frames per second)
	if nargin < 3 || isempty(big_scroll), big_scroll = 30; end  %page-up and page-down advance, in frames
	if nargin < 4, key_func = []; end
	
	%check arguments
	check_callback(redraw_func);
	check_int_scalar(play_fps);
	check_int_scalar(big_scroll);
	check_callback(key_func);

    size_video = [0 0.03 0.87 0.97]; % default video window size within the open window (set same as the original videofig) HO 2/17/2011
    click = 0;
    [ImStk, DotNum, NumRemainingDots] = getNewImageStack();
    num_frames = size(ImStk,3);
	f = ceil(num_frames/2); % Current frame
   
    if NumRemainingDots == 0
        disp('Colocalization analysis complete, no more objects to process.');
        disp(['Colocalization Rate: ' num2str(ColocManual.ColocRate)]);
        return;
    end
    
    %initialize figure
	fig_handle = figure('Name','Colocalization Analysis','NumberTitle','off',...
        'Color',[.3 .3 .3], 'MenuBar','none', 'Units','norm', ...
		'WindowButtonDownFcn',@button_down, 'WindowButtonUpFcn',@button_up, ...
		'WindowButtonMotionFcn', @on_click, 'KeyPressFcn', @key_press, 'windowscrollWheelFcn', @wheel_scroll, varargin{:});
    
	%axes for scroll bar
	scroll_axes_handle = axes('Parent',fig_handle, 'Position',[0 0 1 0.03], ...
		'Visible','off', 'Units', 'normalized');
	axis([0 1 0 1]);
	axis off
	
	%scroll bar
	scroll_bar_width = max(1 / num_frames, 0.01);
	scroll_handle = patch([0 1 1 0] * scroll_bar_width, [0 0 1 1], [.8 .8 .8], ...
		'Parent',scroll_axes_handle, 'EdgeColor','none', 'ButtonDownFcn', @on_click);
	
    set(gcf,'units', 'normalized', 'position', [0.25 0.1 0.455 0.72]);
    uicontrol('Style','text','Units','normalized','position',[.015,.97,.4,.02],'String',['Reference channel: ' ColocManual.Source]);
    uicontrol('Style','text','Units','normalized','position',[.445,.97,.4,.02],'String',['Colocalizing channel: ' ColocManual.Fish1]);
    uicontrol('Style','text','Units','normalized','position',[.015,.05,.4,.02],'String',['Current ' ColocManual.Source ' (magenta)']);
    uicontrol('Style','text','Units','normalized','position',[.445,.05,.4,.02],'String',['Current ' ColocManual.Source ' (magenta),' ColocManual.Fish1 ' (green)']);

    uicontrol('Style','text','Units','normalized','position',[.88,.94,.11,.02],'String','Objects #');
    uicontrol('Style','text','Units','normalized','position',[.88,.92,.11,.02],'String',['Total: ' num2str(ColocManual.TotalNumDotsManuallyColocAnalyzed)]);
    txtCurrent_handle = uicontrol('Style','text','Units','normalized','position',[.88,.90,.11,.02],'String',['Current: ' num2str(DotNum)]);
    txtRemaining_handle = uicontrol('Style','text','Units','normalized','position',[.88,.88,.11,.02],'String',['Remaining: ' num2str(NumRemainingDots)]);

    uicontrol('Style','Pushbutton','Units','normalized','position',[.88,.70,.11,.05], 'String','Reset last choice','CallBack',@btnResetLast_clicked);    
    uicontrol('Style','Pushbutton','Units','normalized','position',[.88,.58,.11,.1], 'String','Colocalized','CallBack',@btnColocalized_clicked);
    uicontrol('Style','Pushbutton','Units','normalized','position',[.88,.47,.11,.1], 'String','Not colocalized','CallBack',@btnNotColocalized_clicked);
    uicontrol('Style','Pushbutton','Units','normalized','position',[.88,.09,.11,.05], 'String','Save','Callback',@btnSave_clicked);    
    uicontrol('Style','Pushbutton','Units','normalized','position',[.88,.03,.11,.05], 'String','Exit','Callback','close');    
    
	% Timer to play video
	play_timer = timer('TimerFcn',@play_timer_callback, 'ExecutionMode','fixedRate');
	
	% Main drawing axes for video display
    if size_video(2) < 0.03; size_video(2) = 0.03; end; %bottom 0.03 must be used for scroll bar HO 2/17/2011
	axes_handle = axes('Position',size_video); %[0 0.03 1 0.97] to size_video (6th input argument) to allow space for buttons and annotations 2/13/2011 HO
    
	% Return handles and initial call to redraw_func
	scroll_bar_handles = [scroll_axes_handle; scroll_handle];
	scroll_func = @scroll;
    scroll(f);
    uiwait;
    
    function [ImStk, DotNum, NumRemainingDots] = getNewImageStack()
        RemainingDotIDs = ColocManual.ListDotIDsManuallyColocAnalyzed(ColocManual.ColocFlag == 0);
        NumRemainingDots = length(RemainingDotIDs);
        if NumRemainingDots > 0 
            dot = ceil(rand*NumRemainingDots); % randomize the order of analyzing dots
            DotNum = RemainingDotIDs(dot);
            PostVoxMap = zeros(size(Post), 'uint8');
            PostVoxMap(Grouped.Vox(DotNum).Ind) = 1;
            CutNumVox = [60, 60, 20];
            PostCut = colocDotStackCutter(Post, Grouped, DotNum, [], CutNumVox);
            ColoCut = colocDotStackCutter(Colo, Grouped, DotNum, [], CutNumVox);
            PostVoxMapCut = colocDotStackCutter(PostVoxMap, Grouped, DotNum, [], CutNumVox);
            
            MaxRawBright = max(Grouped.Vox(DotNum).RawBright);
            %PostMaxRawBright = single(max(PostCut(:)));
            ColoMaxRawBright = single(max(ColoCut(:)));
            PostUpperLimit = 200;
            ColoUpperLimit = 200;
            PostScalingFactor = PostUpperLimit/MaxRawBright; % Normalized to brightness of the current object
            ColoScalingFactor = ColoUpperLimit/ColoMaxRawBright; % Normalized to the local field's brightness
            
            PostCutScaled = uint8(single(PostCut)*single(PostScalingFactor));
            ColoCutScaled = uint8(single(ColoCut)*single(ColoScalingFactor));
            ZeroCut = uint8(zeros(size(PostCut)));
            
            ImStk1 = cat(4, PostCutScaled, PostCutScaled, PostCutScaled);
            ImStk2 = cat(4, ColoCutScaled, ColoCutScaled, ColoCutScaled);
            ImStk3 = cat(4, PostCutScaled.*PostVoxMapCut, ZeroCut, PostCutScaled.*PostVoxMapCut);
            ImStk4 = cat(4, PostCutScaled.*PostVoxMapCut, ColoCutScaled, PostCutScaled.*PostVoxMapCut);
            ImStk = cat(1, cat(2, ImStk1, ImStk2),  cat(2, ImStk3, ImStk4));
        else
            % Add stats so that you can remember ColocFlag of 1 is coloc, etc.
            ColocManual.NumDotsColoc = length(find(ColocManual.ColocFlag == 1));
            ColocManual.NumDotsNonColoc = length(find(ColocManual.ColocFlag == 2));
            ColocManual.NumFalseDots = length(find(ColocManual.ColocFlag == 3));
            ColocManual.ColocRate = ColocManual.NumDotsColoc/(ColocManual.NumDotsColoc+ColocManual.NumDotsNonColoc);
            ColocManual.FalseDotRate = ColocManual.NumFalseDots/(ColocManual.NumDotsColoc+ColocManual.NumDotsNonColoc+ColocManual.NumFalseDots);
            ColocManual.ColocRateInclugingFalseDots = ColocManual.NumDotsColoc/(ColocManual.NumDotsColoc+ColocManual.NumDotsNonColoc+ColocManual.NumFalseDots);            
            if exist([Settings.TPN 'Coloc.mat'], 'file')
                load([Settings.TPN 'Coloc.mat']);
                Coloc(end+1) = ColocManual;
            else
                Coloc = ColocManual;
            end
            save([Settings.TPN 'Coloc.mat'], 'Coloc'); % Add completed analusis to Coloc
            if exist([Settings.TPN 'ColocManual.mat'], 'file')
                delete([Settings.TPN 'ColocManual.mat']); % Remove temporary ColocManual
            end
            ImStk = [];
            DotNum = 0;
            return;
        end
    end
    
    function btnResetLast_clicked(~, ~)
        ColocManual.ColocFlag(ColocManual.ListDotIDsManuallyColocAnalyzed==DotNum)=0;
        [ImStk, DotNum, NumRemainingDots] = getNewImageStack();
        set(txtCurrent_handle,'string',['Current: ' num2str(DotNum)]);
        set(txtRemaining_handle,'string',['Remaining: ' num2str(NumRemainingDots)]);
        num_frames = size(ImStk,3);
        f = ceil(num_frames/2); % Current frame
        scroll(f);
        msgbox('Last object will be examined again in random order.');
    end

    function btnColocalized_clicked(~, ~)
        ColocManual.ColocFlag(ColocManual.ListDotIDsManuallyColocAnalyzed==DotNum)=1;
        [ImStk, DotNum, NumRemainingDots] = getNewImageStack();
        set(txtCurrent_handle,'string',['Current: ' num2str(DotNum)]);
        set(txtRemaining_handle,'string',['Remaining: ' num2str(NumRemainingDots)]);        
        num_frames = size(ImStk,3);
        f = ceil(num_frames/2); % Current frame
        scroll(f);
    end

    function btnNotColocalized_clicked(~, ~)
        ColocManual.ColocFlag(ColocManual.ListDotIDsManuallyColocAnalyzed==DotNum)=2;
        [ImStk, DotNum, NumRemainingDots] = getNewImageStack();
        set(txtCurrent_handle,'string',['Current: ' num2str(DotNum)]);
        set(txtRemaining_handle,'string',['Remaining: ' num2str(NumRemainingDots)]);        
        num_frames = size(ImStk,3);
        f = ceil(num_frames/2); % Current frame
        scroll(f);        
    end

    function btnSave_clicked(~, ~)
        save([Settings.TPN 'ColocManual.mat'], 'ColocManual');
        msgbox('Progress saved.');        
    end
    
    function wheel_scroll(~, event)
          if event.VerticalScrollCount < 0
              %disp('scroll up');
              %position = get(scroll_handle, 'XData');
              %disp(position);
              scroll(f+1);
          elseif event.VerticalScrollCount > 0
              %disp('scroll down');
              scroll(f-1);
          end
    end
    
	function key_press(src, event)  %#ok, unused arguments
		switch event.Key  %process shortcut keys
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
			play(1/play_fps)
		case 'backspace'
			play(5/play_fps)
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
		if click_pos(2) <= 0.03  %only trigger if the scrollbar was clicked
			click = 1;
			on_click([],[]);
		end
	end

	function button_up(src, event)  %#ok, unused arguments
		click = 0;
	end

	function on_click(src, event)  %#ok, unused arguments
		if click == 0, return; end
		
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
	end

	function play(period)
		%toggle between stoping and starting the "play video" timer
		if strcmp(get(play_timer,'Running'), 'off')
			set(play_timer, 'Period', period);
			start(play_timer);
		else
			stop(play_timer);
		end
	end
	function play_timer_callback(src, event)  %#ok
		%executed at each timer period, when playing the video
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
		redraw_func(f, ImStk);
		
		%used to be "drawnow", but when called rapidly and the CPU is busy
		%it didn't let Matlab process events properly (ie, close figure).
		pause(0.001)
	end
	
	%convenience functions for argument checks
	function check_int_scalar(a)
		assert(isnumeric(a) && isscalar(a) && isfinite(a) && a == round(a), ...
			[upper(inputname(1)) ' must be a scalar integer number.']);
	end
	function check_callback(a)
		assert(isempty(a) || isa(a, 'function_handle'), ...
			[upper(inputname(1)) ' must be a valid function handle.'])
    end

end

