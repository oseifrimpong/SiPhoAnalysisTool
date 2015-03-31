classdef peakClass < handle
    %Summary of this class goes here
    %   Detailed explanation goes here
    
    % Raw fit: simple min/max operation depending of self.isPeak.
    % manual: crosshair to choose peak manually
    % poly fit:
    % lorentzian fit:
    properties (Access = public)
        raw; % struct for raw data
        useFit;
        DEBUG = false;
    end
    
    properties (Access = protected)
        fit; % struct for fit data
        guiHandles; % structure of all the handles associated w/ gui_figure_handle
        userResponse; % for debugging
    end
    
    properties (Constant)
        fitTypeOptions = {'Raw', 'Manual', 'Poly', 'Lorentz'}; % others? These values should populate a pop-up
        LB = 1; % lower bound array index
        C = 2; % center array index
        UB = 3; % upper bound array index
        %used to access self.fit.window = [715, 1430, 2215];
    end
    
    %% methods
    methods
        %% constructor
        function self = peakClass(peakInfo)
            self.userResponse = ''; % for debugging
            
            self.raw.corrRho = [];
            self.raw.corrPval = [];
            % default values that should get overwritten by data load from disk
            self.fit.type = 'Raw';
            self.fit.params.windowSize = 1; %nm -- should be user inut
            self.fit.params.fitOrder = 3; % --- should be user input
            self.fit.stepSizeWvl = 0.001; % nm, default value
            self.fit.pval = inf; % measure of correlation
            self.fit.rho = inf; % measure of correlation
            self.fit.resnorm = inf; % measure of goodness of fit: norm of the residuals
            self.fit.Q = inf; % fitted peak Q est.
            self.fit.QMin3dBWvl = inf; % lower bound for Q est.
            self.fit.QMax3dBWvl = inf; % upper bound for Q est.
            self.fit.wvls = [];
            self.fit.pwrs = [];
            % for fit optimization engine
            self.fit.params.fitOptimizationWindowSize = 0.1; % in %, default value, 0=disable
            self.fit.params.fitOptimizationStepSize_nm = 10; % nm, default value, 0=disable
            %self.fit.params.fitEngineSlideStep = 0.1; % in %, default value, 0=disable
            %self.fit.params.fitEngineSlideIterations = 10; % nm, default value, 0=disable
            self.fit.bestFit.windowSize = 0; % default value
            self.fit.bestFit.windowOffsetFromRawPeakWindow = 0; % position offset from raw peak w/in raw window
            self.fit.useFitOptimizer = false;
            
            self.useFit = false; % default value;
            %class
            self.fit.reviewed = false;
            
            %% raw data (provided as input when object is created)
            % raw peak info is passed from scanClass when object is created
            % shons reference only (copied from scanClass.m)
            %   peakInfo = struct(...
            %       'isPeak', self.raw.isPeakInfo(pp), ...
            %       'peakWvl', wvlPeak, ...
            %       'peakPwr', pwrPeak, ...
            %       'wvls', self.wvl(windowLeftIndex:windowRightIndex), ...
            %       'pwrs', self.pwr(windowLeftIndex:windowRightIndex));
            
            self.updatePeakInfo(peakInfo);
            
            %% default values for peak fitting and window
            % these defaults need to be set in the constructor so that
            % previously saved data can be loaded afterwards
            % slide bar steps and center (for default)
            
        end % constructor
        
        %% updatePeakInfo
        function updatePeakInfo(self, peakInfo)
            infoNames = fieldnames(peakInfo);
            for n = 1:length(infoNames)
                self.raw.(infoNames{n}) = peakInfo.(infoNames{n});
            end
            if self.DEBUG
                msg=strcat('length of raw.wvls=', num2str(length(self.raw.wvls)));
                disp(msg);
                msg=strcat('range of raw.wvls=', num2str(self.raw.wvls(end)-self.raw.wvls(1)));
                disp(msg);
                msg=strcat('step=', num2str(self.raw.wvls(2)-self.raw.wvls(1)));
                disp(msg);
            end
            %Notes: the updates would consist of new PeakWvl and range
            %update fit parmaters and fit wondow
            
            % uses the self.raw.PeakWvl as center wavelength
            self.initializeFitWindowBounds();
            self.fitPeak();
        end
        
        %% initializeFitWindowBounds
        function self = initializeFitWindowBounds(self)
            % set initial value for fit window based on updated raw data
            % set fit window at 1/2 size of total raw data window
            self.fit.params.windowSize = (self.raw.wvls(end)-self.raw.wvls(1))/2;
            
            % set initial window center index
            self.fit.window(self.C) = find(self.raw.wvls == self.raw.peakWvl); %there is only one value
            % set L and R fit window bounds index w/ default window size
            step = self.raw.wvls(2)-self.raw.wvls(1); % resolution
            self.fit.window(self.LB) = ceil(self.fit.window(self.C) -...
                self.fit.params.windowSize/step/2);
            self.fit.window(self.UB) = floor(self.fit.window(self.C) +...
                self.fit.params.windowSize/step/2);
            % set limits
            if self.fit.window(self.LB) < 1
                self.fit.window(self.LB) = 1; % first value in array
            end
            if self.fit.window(self.UB) > length(self.raw.wvls)
                self.fit.window(self.UB) = length(self.raw.wvls); % last value in array
            end
            % initialize fit value variables (set to raw initially)
            self.fit.peakWvl = self.raw.peakWvl;
            self.fit.peakPwr = self.raw.peakPwr;
            if self.DEBUG
                msg=strcat('fit.window(self.LB)=', num2str(self.fit.window(self.LB)));
                disp(msg);
                msg=strcat('fit.window(self.C)=', num2str(self.fit.window(self.C)));
                disp(msg);
                msg=strcat('fit.window(self.UB)=', num2str(self.fit.window(self.UB)));
                disp(msg);
                msg=strcat('fit.peakWvl=', num2str(self.fit.peakWvl));
                disp(msg);
                msg=strcat('fit.peakPwr=', num2str(self.fit.peakPwr));
                disp(msg);
            end
            % determine number of steps for slider in plot window
            self.fit.windowSteps = (self.raw.wvls(end)-...
                self.raw.wvls(1))/self.fit.stepSizeWvl;
            % set slidebar to the middle (index of raw.wvls)
            self.fit.slidebarPosition = round(self.fit.windowSteps/2);
        end
        
        %% openPeakFitWindow
        function self = openPeakFitWindow(self)
            % create popup window gui
            gui_figure_handle = peakFittingGUI(); % draws gui returns handles
            self.guiHandles = guidata(gui_figure_handle); % gui_figure_handle = 'handle to figure' self.gui is structure of all the handles associated w/ gui_figure_handle
            
            %% update other gui stuff
            set(self.guiHandles.fitTypePopup, 'String', self.fitTypeOptions);
            
            %% callback mapping to class methods
            set(self.guiHandles.fitTypePopup, 'callback',@self.fitTypePopup_callback);
            set(self.guiHandles.resetButton, 'callback',@self.resetButton_callback);
            %            set(self.guiHandles.selectPeakButton, 'callback',@self.selectPeakButton_callback);
            set(self.guiHandles.fitWinPosSlider, 'callback',@self.fitWinPosSlider_callback);
            set(self.guiHandles.fitWindowStepSizeValue, 'callback',@self.fitWindowStepSizeValue_callback);
            set(self.guiHandles.fitPeakWinSizeValue, 'callback',@self.fitPeakWinSizeValue_callback);
            set(self.guiHandles.fitParametersButton, 'callback',@self.fitParametersButton_callback);
            set(self.guiHandles.closeButton, 'callback',@self.closeButton_callback);
            set(self.guiHandles.refitButton, 'callback',@self.refitButton_callback);
            set(self.guiHandles.reviewedCheckbox, 'callback',@self.reviewedCheckbox_callback);
            set(self.guiHandles.reviewedCheckbox, 'Value', self.fit.reviewed);
            set(self.guiHandles.useFitOptimizerCheckbox, 'callback',@self.useFitEngineCheckbox_callback);
            
            % update slidebar
            self.updateSlideBar();
            % plot raw data
            self.updategui();
        end % function openPeakFitWindow
        
        %% update GUI elements (slider, text boxes, and plots
        % update gui text boxes
        function updateGuiTextBoxes(self)
            %% write initial values to these status boxes
            set(self.guiHandles.rawPeakWvlValue, 'String',num2str(self.raw.peakWvl));
            set(self.guiHandles.fitPeakWvlValue, 'String',num2str(self.fit.peakWvl));
            set(self.guiHandles.differenceValue, 'String',num2str(abs(self.raw.peakWvl-self.fit.peakWvl)*1000));
            set(self.guiHandles.fitGoodnessValue, 'String',num2str(self.fit.resnorm));
            set(self.guiHandles.rawPeakWinSizeValue, 'String',num2str(self.raw.wvls(end)-self.raw.wvls(1)));
            set(self.guiHandles.fitWindowStepSizeValue, 'String',num2str(self.fit.stepSizeWvl*1e3));
            set(self.guiHandles.fitPeakWinSizeValue, 'String',num2str(self.fit.params.windowSize));
            
            %update pull down menu for fit type
            selectedVal = find(strcmp(self.fit.type,self.fitTypeOptions));
            set(self.guiHandles.fitTypePopup,'Value',selectedVal);
            set(self.guiHandles.useFitOptimizerCheckbox, 'Value', self.fit.useFitOptimizer);
            
            
        end
        
        %% update figure plot
        function updatePlot(self)
            %% plot raw data
            plot(self.guiHandles.plotWin, self.raw.wvls, self.raw.pwrs, 'b');
            % set x and y limits before hold on
            xlim([self.raw.wvls(1) self.raw.wvls(end)]);
            hold(self.guiHandles.plotWin, 'on');
            plot(self.guiHandles.plotWin, self.raw.peakWvl, self.raw.peakPwr, 'b+');
            
            %% fit window
            % plot fit window lines, get ylimits and window edge indices
            yLimit = get(self.guiHandles.plotWin, 'ylim');
            %             fitWindowMinWvl = self.fit.windowWvl(self.C) - self.fit.params.windowSize/2  %peak is centered
            %             fitWindowMaxWvl = self.fit.windowWvl(self.C) + self.fit.params.windowSize/2  %peak is centered
            
            %% plot fit
            plot(self.guiHandles.plotWin, self.fit.peakWvl, self.fit.peakPwr, 'r+'); % crosshair at peak
            if ~isempty(self.fit.wvls)
                plot(self.guiHandles.plotWin, self.fit.wvls, self.fit.pwrs, 'r-'); % plot waveform
            end
            legend(self.guiHandles.plotWin, 'Raw', 'RawPeak', 'FitPeak', 'Fit');
            
            % lower bound
            plot(self.guiHandles.plotWin, self.raw.wvls(self.fit.window(self.LB)), linspace(yLimit(1), yLimit(2), 100), 'r--');
            % upper bound
            plot(self.guiHandles.plotWin, self.raw.wvls(self.fit.window(self.UB)), linspace(yLimit(1), yLimit(2), 100), 'r--');
            
            % turn off hold
            hold(self.guiHandles.plotWin, 'off');
        end
        
        
        %% callbacks for gui
        function self = fitTypePopup_callback(self, hObject, eventData)
            % get user selection
            selectedVal = get(hObject, 'Value');
            % index into options to determine fit type
            self.fit.type = self.fitTypeOptions{selectedVal};
            % fit
            self.fitPeak();
            self.updategui();
        end % function fitTypePopup_callback
        
        function self = resetButton_callback(self, hObject, eventData)
            % reset fit window the center
            % total number of fit window steps in raw plot window
            self.fit.windowSteps = (self.raw.wvls(end)-...
                self.raw.wvls(1))/self.fit.stepSizeWvl;
            % set slidebar assume fit window starts in the middle (index of raw.wvls)
            self.fit.slidebarPosition = round(self.fit.windowSteps/2);
            % update slidebar
            self.updateSlideBar();
            % refit data
            self.fitPeak();
            
            % plot raw data
            self.updategui();
        end % function resetButton_callback
        
        function self = selectPeakButton_callback(self, hObject, eventData)
            axes(self.guiHandles.plotWin);
            [selWvl, selPwr, button] = ginput(1);
            if button == 1
                self.fit.peakWvl = selWvl;
                self.fit.peakPwr = selPwr;
                self.fit.resnorm = inf; %no fit.
                self.updategui();
            end
        end % function selectPeakButton_callback
        
        function self = fitPeakWinSizeValue_callback(self, hObject, eventData)
            sizeStr = get(hObject, 'String');
            % check win size smaller than raw window, if not, set to max
            if str2num(sizeStr) < self.raw.wvls(end)-self.raw.wvls(1)
                self.fit.params.windowSize = str2num(sizeStr);
            else
                self.fit.params.windowSize = self.raw.wvls(end)-self.raw.wvls(1);
            end
            % update fit window
            self.updateFitWindowBoundsForGuiOnly();
            self.fitPeak();
            self.updategui();
        end % function fitPeakWinSizeValue_callback
        
        %% slide bar and fit window manipulation
        function self = fitWinPosSlider_callback(self, hObject, eventData)
            % get new position
            self.fit.slidebarPosition = round(get(self.guiHandles.fitWinPosSlider, 'Value'));
            % update indices
            self.updateSlideBar();
            self.fitPeak();
            self.updategui();
        end % function fitWinPosSlider_callback
        
        
        function self = updateSlideBar(self)
            set(self.guiHandles.fitWinPosSlider, 'Min', 1);
            steps = round((self.raw.wvls(end)-self.raw.wvls(1))/self.fit.stepSizeWvl);
            if self.DEBUG
                msg=strcat('updateSlideBar => self.fit.slideBarPosition =', num2str(self.fit.slidebarPosition));
                disp(msg);
                msg=strcat('updateSlideBar => steps =', num2str(steps));
                disp(msg);
            end
            set(self.guiHandles.fitWinPosSlider, 'Max', steps);
            set(self.guiHandles.fitWinPosSlider, 'SliderStep', [1 1]/steps);
            set(self.guiHandles.fitWinPosSlider, 'Value', self.fit.slidebarPosition);
            % update fit window
            self.updateFitWindowBoundsForGuiOnly();
        end
        
        %% update fit window bounds
        function self = updateFitWindowBoundsForGuiOnly(self)
            resolution = self.raw.wvls(2)-self.raw.wvls(1);
            % calculate index from slider position into raw.wvls array
            self.fit.window(self.C) = round(self.fit.slidebarPosition*...
                self.fit.stepSizeWvl/resolution);
            % number of points in 1/2 window size
            windowEdgeOffset = round(self.fit.params.windowSize/resolution/2);
            % determine window LB or limit
            if self.fit.window(self.C) - windowEdgeOffset < 1
                disp('LB limit');
                self.fit.window(self.LB)=1;
            else
                self.fit.window(self.LB) = round(self.fit.window(self.C)-...
                    windowEdgeOffset);
            end
            % determine window UB or limit
            if self.fit.window(self.C) + windowEdgeOffset > length(self.raw.wvls)
                disp('UB limit');
                self.fit.window(self.UB)=length(self.raw.wvls);
            else
                self.fit.window(self.UB) = round(self.fit.window(self.C)+...
                    windowEdgeOffset);
            end
            if self.DEBUG
                msg=strcat('updateFitWindowBoundsForGuiOnly => self.fit.params.windowSize=', num2str(length(self.fit.params.windowSize)));
                disp(msg);
                msg=strcat('updateFitWindowBoundsForGuiOnly => length of raw.wvls=', num2str(length(self.raw.wvls)));
                disp(msg);
                msg=strcat('updateFitWindowBoundsForGuiOnly => resolution=', num2str(resolution));
                disp(msg);
                msg=strcat('updateFitWindowBoundsForGuiOnly => windowEdgeOffset=', num2str(windowEdgeOffset));
                disp(msg);
                msg=strcat('updateFitWindowBoundsForGuiOnly => window(self.LB)=', num2str(self.fit.window(self.LB)));
                disp(msg);
                msg=strcat('updateFitWindowBoundsForGuiOnly => window(self.C)=', num2str(self.fit.window(self.C)));
                disp(msg);
                msg=strcat('updateFitWindowBoundsForGuiOnly => window(self.UB)=', num2str(self.fit.window(self.UB)));
                disp(msg);
            end
            set(self.guiHandles.fitWinCenterValue, 'String',...
                num2str(self.raw.wvls(self.fit.window(self.C))));
            
            %             % calculate LB and UB fit window
            %             self.raw.wvls(self.fit.window(self.LB)) = self.raw.wvls(self.fit.window(self.C)) -...
            %                 self.fit.params.windowSize/2;
            %             self.raw.wvls(self.fit.window(self.UB)) = self.raw.wvls(self.fit.window(self.C)) +...
            %                 self.fit.params.windowSize/2;
        end
        
        %% updateFitWindowBounds
        function self = updateFitWindowBounds(self)
            % no gui elemeents used in this method
            % update L and R window bounds around current C (if fit.windowSize chagnes)
            resolution = self.raw.wvls(2)-self.raw.wvls(1);
            %             % calculate index from slider position into raw.wvls array
            %             self.fit.window(self.C) = round(self.fit.slidebarPosition*...
            %                 self.fit.stepSizeWvl/resolution);
            % number of points in 1/2 window size
            windowEdgeOffset = round(self.fit.params.windowSize/resolution/2);
            % determine window LB or limit
            if self.fit.window(self.C) - windowEdgeOffset < 1
                self.fit.window(self.LB)=1;
            else
                self.fit.window(self.LB) = round(self.fit.window(self.C)-...
                    windowEdgeOffset);
            end
            % determine window UB or limit
            if self.fit.window(self.C) + windowEdgeOffset > length(self.raw.wvls)
                self.fit.window(self.UB)=length(self.raw.wvls);
            else
                self.fit.window(self.UB) = round(self.fit.window(self.C)+...
                    windowEdgeOffset);
            end
        end
        
        %% fit param callbacks and functions
        function self = fitWindowStepSizeValue_callback(self, hObject, eventData)
            sizeStr = get(hObject, 'String');
            self.fit.stepSizeWvl = str2num(sizeStr)/1e3;
            % total number of fit window steps in raw plot window
            self.fit.windowSteps = (self.raw.wvls(end)-...
                self.raw.wvls(1))/self.fit.stepSizeWvl;
            % set slidebar assume fit window starts in the middle (index of raw.wvls)
            self.fit.slidebarPosition = round(self.fit.windowSteps/2);
            self.updateSlideBar();
            self.fitPeak();
            self.updategui();
        end % function fitWindowStepSizeValue_callback
        
        % update text strings and plot
        function updategui(self)
            self.updateGuiTextBoxes();
            self.updatePlot();
        end
        
        function self = fitParametersButton_callback(self, hObject, eventData)
            fitParamsFields = fieldnames(self.fit.params);
            prompt = {'Fit Type'};
            defaultAnswer = {self.fit.type};
            name = 'Peak Fitting Setting';
            numlines = 1;
            
            disp(num2str(length(fitParamsFields)));
            
            for ff = 1:length(fitParamsFields)
                prompt{end + 1} = fitParamsFields{ff};
                defaultAnswer{end + 1} = num2str(self.fit.params.(fitParamsFields{ff}));
            end
            % popup user dialog window
            answer = inputdlg(prompt, name, numlines, defaultAnswer);
            
            self.fit.type = answer{1};
            for ff = 1:length(fitParamsFields)
                self.fit.params.(fitParamsFields{ff}) = str2double(answer{ff + 1});
            end
            % update fit window
            self.updateFitWindowBoundsForGuiOnly();
            % fit
            self.fitPeak();
            % update gui
            self.updategui();
        end % function fitParametersButton_callback
        
        function closeButton_callback(self, hObject, eventData)
            uiresume;
            panelObj = get(hObject, 'parent'); % panel window
            delete(get(panelObj, 'parent')); % main window
        end % function closeButton_callback
        
        function refitButton_callback(self, hObject, eventData)
            if self.fit.useFitOptimizer && ~strcmpi(self.fit.type, 'Raw')
                resolution = self.raw.wvls(2)-self.raw.wvls(1);
                if self.fit.params.fitOptimizationStepSize_nm < resolution
                    self.fit.params.fitOptimizationStepSize_nm = resolution;
                end
                startWindowSize = self.fit.params.windowSize;
                windowRange = startWindowSize*self.fit.params.fitOptimizationWindowSize;
                differenceArray = [];
                resnormArray = [];
                windowSizeArray = [];
                for thisWindowSize = startWindowSize+windowRange:-self.fit.params.fitOptimizationStepSize_nm:startWindowSize-windowRange
                    self.fit.params.windowSize = thisWindowSize;
                    self.updateFitWindowBoundsForGuiOnly();
                    self.fitPeak();
                    self.updategui();
                    resnormArray(end+1) = self.fit.resnorm;
                    differenceArray(end+1) = abs(self.raw.peakWvl-self.fit.peakWvl)*1000;
                    windowSizeArray(end+1) = thisWindowSize;
                    pause(0.01)
                end
                [minResult, bestWindowIndex] = min(resnormArray);
                bestWindowSize = windowSizeArray(bestWindowIndex);
                self.fit.params.windowSize = bestWindowSize;
                self.fitPeak();
                self.updategui();
            else
                self.fitPeak();
                self.updatePlot();
            end
        end % function refitButton
        
        %% Correlation
        function correlation(self, previousPeakWvl, previousPeakPwr)
            % the previous peak is passed in
            if self.fit.menuBarPeak.normalizeCorrelation
                thisPeakPwr = self.raw.pwrs - max(self.raw.pwrs);
                previousPeakPwr = previousPeakPwr - max(previousPeakPwr);
            else
                thisPeakPwr = self.raw.wvls;
            end
            
            % create wvl/pwr arrays for comparison
            thisPeak = [self.raw.wvls*e9 thisPeakPwr]; % create matrix
            previousPeak = [previousPeakWvl*e9 previousPeakPwr]; % create matrix
            
            [self.fit.rho, self.fit.pval] = corr(previousPeak, thisPeak, 'type', 'Pearson');
        end
        
        %% fitPeak
        function fitPeak(self)
            % defaults
            %            set(self.guiHandles.selectPeakButton, 'Enable', 'off');
            % clear fit wvl and pwr data
            self.fit.pwrs = [];
            self.fit.wvls = [];
            
            switch self.fit.type
                case 'Raw'
                    %                     self.fit.peakWvl = self.raw.peakWvl;
                    %                     self.fit.peakPwr = self.raw.peakPwr;
                    self.rawFit();
                case 'Manual'
                    % enable peak select button
                    %                    set(self.guiHandles.selectPeakButton, 'Enable', 'on');
                    self.selectPeakButton_callback();
                case 'Poly'
                    self.polyFit();
                case 'Lorentz'
                    self.lorentzFit();
                    %if self.fit.useFitOptimizer
                    % save off existing parameters
                    
                    % determine loop parameters, loop on 2 things
                    %   window size
                    %   window position around peak location
                    % slide the window for a given size
                    %                         lb = -round(self.fit.params.fitEngineSlideIterations/2);
                    %                         ub = round(self.fit.params.fitEngineSlideIterations/2);
                    %                         for ii=lb:1:ub
                    %                             % adjust new window size
                    %                             windowSize = self.fit.window(self.UB) -...
                    %                                 self.fit.window(self.LB);
                    %                             numWindowPositions = (windowSize/...
                    %                                 self.fit.params.fitEngineSlideStep/...
                    %                                 self.fit.params.fitEngineSlideIterations);
                    %                             % eg: if win=100pm, scale=.1, and iter=10
                    %                             %   sweep win=110pm downto 90pm in 10 steps
                    %                             numberWindowSizeSteps = (self.fit.params.windowSize * ...
                    %                                 self.fit.params.fitOptimizationWindowSize*2)/...
                    %                                 self.fit.params.fitOptimizationStepSize_nm;
                    %                             for jj=1:numberWindowSizeSteps
                    %                                 self.lorentzFit();
                    %                                 % check for best value
                    %                                 self.fit.bestFit.windowSize = 0; % default value
                    %                                 self.fit.bestFit.windowOffsetFromRawPeakWindow = 0; % position offset from raw peak w/in raw window
                    %                             end
                    %                         end
                    
                    %end % if self.fit.useFitOptimizer
                otherwise
                    questdlg('You should not end up here...',...
                        'Uh Oh',...
                        'OK');
            end
            % can't update the gui since the scanClass calls this method.
            %             % update gui
            %             self.updategui();
        end
        
        function [fitType, fitParams] = getFitParams(self)
            fitType = self.fit.type;
            fitParams = self.fit.params;
            if self.DEBUG
                msg = strcat(...
                    '::fitType=',fitType,...
                    '::fitParams.windowSize=',num2str(fitParams.windowSize));
                disp(msg);
                if ~strcmp(self.userResponse,'c') % continue to end
                    self.userResponse = input('In peak class getFitParams::Continue? [<CR> -or- c to continuous] = ','s'); % returns as string
                end
            end
        end
        
        function setFitParams(self, newFitType, newFitParams)
            self.fit.type = newFitType;
            self.fit.params = newFitParams;
            if self.DEBUG
                msg = strcat(...
                    '::fitType=',self.fit.type,...
                    '::fitParams.windowSize=',num2str(self.fit.params.windowSize));
                disp(msg);
                if ~strcmp(self.userResponse,'c') % continue to end
                    self.userResponse = input('In peak class setFitParams::Continue? [<CR> -or- c to continuous] = ','s'); % returns as string
                end
            end
            self.updateFitWindowBounds();
            self.fitPeak();
        end
        
        %% Raw fit
        function self = rawFit(self)
            %doesn't have any fit wvls and pwrs; just copy the raw data
            %over and do min/max on the fitted.
            if self.DEBUG
                msg=strcat('index LB => self.fit.window(self.LB)=',num2str(self.fit.window(self.LB)) );
                disp(msg);
                msg=strcat('index UB => self.fit.window(self.UB)=',num2str(self.fit.window(self.UB)) );
                disp(msg);
            end
            self.fit.wvls = self.raw.wvls(self.fit.window(self.LB):self.fit.window(self.UB));
            self.fit.pwrs = self.raw.pwrs(self.fit.window(self.LB):self.fit.window(self.UB));
            % find maxima within fit window
            if self.raw.isPeak
                [self.fit.peakPwr, index] = max(self.fit.pwrs);
            else
                [self.fit.peakPwr, index] = min(self.fit.pwrs);
            end
            
            self.fit.peakWvl = self.fit.wvls(index(end));
            self.raw.peakWvl = self.fit.peakWvl;
            self.raw.peakPwr = self.fit.peakPwr; 
            
            %need to update; in case polyfit was done bofore.
            self.fit.resnorm = inf; %no fit.
            
            if self.DEBUG
                msg=strcat('rawFit => self.fit.window(self.LB)=', num2str(self.fit.window(self.LB)));
                disp(msg);
                msg=strcat('rawFit => self.fit.window(self.UB)=', num2str(self.fit.window(self.UB)));
                disp(msg);
                msg=strcat('rawFit => self.fit.peakWvl=', num2str(self.fit.peakWvl));
                disp(msg);
                msg=strcat('rawFit => self.fit.peakPwr=', num2str(self.fit.peakPwr));
                disp(msg);
                msg=strcat('rawFit => self.raw.wvls(1)=', num2str(self.raw.wvls(1)));
                disp(msg);
                msg=strcat('rawFit => self.raw.wvls(end)=', num2str(self.raw.wvls(end)));
                disp(msg);
                msg=strcat('rawFit => length(self.raw.wvls)=', num2str(length(self.raw.wvls)));
                disp(msg);
                msg=strcat('rawFit => length(self.fit.wvls)=', num2str(length(self.fit.wvls)));
                disp(msg);
            end
        end
        
        %% Poly fit
        function self = polyFit(self)
            %             fitWindowMin = self.raw.peakWvl - self.fit.params.windowSize/2;  %peak is centered
            %             fitWindowMax = self.raw.peakWvl + self.fit.params.windowSize/2;  %peak is centered
            fitWindowMin = self.raw.wvls(self.fit.window(self.LB));  %peak is centered
            fitWindowMax = self.raw.wvls(self.fit.window(self.UB));  %peak is centered
            fitWindowLeft = find(fitWindowMin >= self.raw.wvls); %indices
            if fitWindowLeft
                fitWindowLeft = fitWindowLeft(end); %single value
            else
                fitWindowLeft = 1; %outside of scan window; take first point
            end
            fitWindowRight = find(fitWindowMax >= self.raw.wvls);
            fitWindowRight = fitWindowRight(end); %if fitWindowRight out of window this still works
            
            self.fit.wvls = self.raw.wvls(fitWindowLeft:fitWindowRight);
            self.fit.pwrs = self.raw.pwrs(fitWindowLeft:fitWindowRight);
            
            [fitParam, S] = polyfit(self.fit.wvls, self.fit.pwrs, self.fit.params.fitOrder);
            self.fit.pwrs = polyval(fitParam, self.fit.wvls);
            if self.raw.isPeak
                [self.fit.peakPwr, indx] = max(self.fit.pwrs);
            else
                [self.fit.peakPwr, indx] = min(self.fit.pwrs);
            end
            self.fit.peakWvl = self.fit.wvls(indx);
            self.fit.resnorm = S.normr;
            %             % update gui w/ fit plot
            %             self.updategui();
        end
        
        %% Lorentz fit
        function lorentzFit(self)
            
            fitWindowMin = self.raw.wvls(self.fit.window(self.LB));  %peak is centered
            fitWindowMax = self.raw.wvls(self.fit.window(self.UB));  %peak is centered
            if self.DEBUG
                msg=strcat('index LB => self.fit.window(self.LB)=',num2str(self.fit.window(self.LB)) );
                disp(msg);
                msg=strcat('index UB => self.fit.window(self.UB)=',num2str(self.fit.window(self.UB)) );
                disp(msg);
            end
            
            self.fit.wvls = self.raw.wvls(self.fit.window(self.LB):self.fit.window(self.UB));
            self.fit.pwrs = self.raw.pwrs(self.fit.window(self.LB):self.fit.window(self.UB));
            
            %Define lorentz function
            % p1: Area, p2: max location, p3:FWHM, p4: offset
            lorentz_fun = @(p, xdata) ( p(4) + (2*p(1)/pi) .*(p(3)./( 4.*(xdata -p(2)).^2 + p(3)^2 ) ));
            
            %xdata = self.fit.wvls;
            
            %upsample: important for high Q peaks, resulstion ~0.1pm
            xdata = self.fit.wvls(1):(self.fit.wvls(2)-self.fit.wvls(1))/4:self.fit.wvls(end);
            %assumes that ydata is in dBm
            %convert to mW
            %ydata = 10.^(self.fit.pwrs./10);
            ydata = interp1(self.fit.wvls,10.^(self.fit.pwrs./10),xdata,'spline');
            %             ftemp = figure;
            %             hold on
            %             plot(self.fit.wvls ,10.^(self.fit.pwrs./10), 'bo-.');
            %             plot(xdata, ydata, 'rx-');
            %             hold off;
            
            if  ~self.raw.isPeak
                ydata = -1*(ydata - 1); %not sure what will happen if max(ydata)>1)
                if max(ydata)>1
                    warndlg('Something went wrong when converting power in dBm to W','!! Warning !!');
                end
            end
            
            %initial guess for parameters;
            p0(2) = self.raw.wvls(self.fit.window(self.C)); %peak location
            p0(3) = (xdata(end)-xdata(1))/2; %FWHM coarse assumption that window is twice the HWHM
            p0(4) = (max(ydata)-min(ydata))/2; %offset
            p0(1) = p0(3)*(max(ydata)-min(ydata)); %Area : don't know; delta_y * FWHM;
            [pr, resnorm, residual, ~, ~] = lsqcurvefit(lorentz_fun,p0,xdata, ydata);
            
            self.fit.pwrs = pr(4) + ( 2*pr(1)/pi ) *( pr(3)./( 4.*(xdata - pr(2)).^2 + pr(3)^2 ) );
            if self.DEBUG
                %debug_fig = figure;
                disp('fitting parameters:');
                msg=strcat('P(1)=',num2str(pr(1)) );
                disp(msg);
                msg=strcat('P(2)=',num2str(pr(2)) );
                disp(msg);
                msg=strcat('P(3)=',num2str(pr(3)) );
                disp(msg);
                msg=strcat('P(4)=',num2str(pr(4)) );
                disp(msg);
            end
            
            %convert back in dBm
            if ~self.raw.isPeak
                self.fit.pwrs=-self.fit.pwrs+1;
            end
            self.fit.pwrs = 10*log10(self.fit.pwrs);
            self.fit.wvls = xdata;
            %find the actual peak value of the fitted window and save it to
            %peak class
            if self.raw.isPeak
                [self.fit.peakPwr, indx] = max(self.fit.pwrs);
            else
                [self.fit.peakPwr, indx] = min(self.fit.pwrs);
            end
            
            res2norm = -10*log10(sum(abs(residual)));
            self.fit.resnorm =res2norm; %to compare to polyfit. need to translate into dBm
            self.fit.peakWvl = self.fit.wvls(indx);
        end
        
        %% reviewed callback
        function self = reviewedCheckbox_callback(self, hObject, eventData)
            self.fit.reviewed = get(hObject, 'Value');
        end
        
        %% use fit engine callback
        function self = useFitEngineCheckbox_callback(self, hObject, eventData)
            self.fit.useFitOptimizer = get(hObject, 'Value');
        end
        
        %% for backwards compatibility
        % for 'refindPeak' method in scan class
        function vals = peakWvl(self)
            vals = self.raw.peakWvl;
        end
        
        function vals = peakPwr(self)
            vals = self.raw.peakPwr;
        end
        function vals = windowSize(self)
            vals =self.raw.wvls(end)-self.raw.wvls(1);
        end
        function vals = fitWvls(self)
            vals = self.fit.wvls;
        end
        function vals = fitPwrs(self)
            vals = self.fit.pwrs;
        end
        function val = fitPeakWvl(self)
            val = self.fit.peakWvl;
        end
        function val = fitPeakPwr(self)
            val = self.fit.peakPwr;
        end
        
        function setFitType(self, val)
            self.fit.type = val;
        end
        
        function setFitWindow(self,val)
            self.fit.window = val;
        end
        
        function val = getIsPeak(self)
            val = self.raw.isPeak;
        end
        
        function setIsPeak(self,val)
            self.raw.isPeak=val;
        end
        
        function setFitProp(self,prop,val)
            if isfield(self.fit, prop)
                self.fit.(prop) = val;
            else
                msg=strcat('Property ', prop,' does not exist');
                errordlg(msg, 'Peak Property Set Error');
            end
            
        end
        
        function val = getFitProp(self,prop)
            if isfield(self.fit, prop)
                val = self.fit.(prop);
            else
                msg=strcat('Property ', prop,' does not exist');
                errordlg(msg, 'Peak Property Get Error');
            end
            
        end
        
        function setFitParam(self,param,val)
            if isfield(self.fit.params, param)
                self.fit.params.(param) = val;
                if self.DEBUG
                    if ~strcmp(self.userResponse,'c') % continue to end
                        self.userResponse = input('In peak class setFitParam::Continue? [<CR> -or- c to continuous] = ','s'); % returns as string
                    end
                end
                self.updateFitWindowBoundsForGuiOnly();
                self.fitPeak();
            else
                msg=strcat('Param ', param,' does not exist');
                errordlg(msg, 'Peak Param Set Error');
            end
        end
        
        function val = getFitParam(self,param)
            if isfield(self.fit.params, param)
                val = self.fit.params.(param);
                if self.DEBUG
                    if ~strcmp(self.userResponse,'c') % continue to end
                        self.userResponse = input('In peak class getFitParam::Continue? [<CR> -or- c to continuous] = ','s'); % returns as string
                    end
                end
            else
                msg=strcat('Param ', param,' does not exist');
                errordlg(msg, 'Peak Param Get Error');
            end
            
        end
        
        %% for integration
        function val = reviewed(self)
            if self.fit.reviewed
                val = true;
            else
                val = false;
            end
        end
        
        %% save function
        function peakData = savePeakData(self)
            peakData.raw = self.raw;
            peakData.fit = self.fit;
            peakData.useFit = self.useFit;
        end
        
        %% load function
        function self = loadPeakData(self, varargin)
            self.raw = varargin{1}.raw;
            self.fit = varargin{1}.fit;
            self.useFit = varargin{1}.useFit;
            % Vince add this to cope with non-existing
            % properties in old analysis file
            self.fit.useFitOptimizer = false;
            % Delete soon ----------------------------------
        end
        %% Calcualte Q values
        function self = calculateQ(self)
            
            %max iteration to find 3dB points (necessary if small peaks
            resolution = self.fit.wvls(2)-self.fit.wvls(1);
            max_iter = 3/resolution;    %if 3nm on either side then no peak
            pwrs = self.fit.pwrs;
            if ~self.raw.isPeak % null
                baseline = mean([self.fit.pwrs(1:10);self.fit.pwrs(end - 9:end)]);
                minPwrIndex = find(self.fit.wvls == self.fit.peakWvl);
                minPwr = pwrs(minPwrIndex(end));
                
                % calculate Q = full width at half max
                leftPwr = minPwr;
                leftPwrIndex = minPwrIndex;
                rightPwr = minPwr;
                rightPwrIndex = minPwrIndex;
                % start at the top and go left
                ii = 0;
                while (leftPwr < baseline - 3) % 3dB down
                    % decrement index and check power val
                    leftPwrIndex = leftPwrIndex-1; % decrement by 1
                    leftPwr = pwrs(leftPwrIndex);
                    if ii>max_iter
                        break;
                    else
                        ii=ii+1;
                    end
                end
                % go right
                ii=0;
                while (rightPwr < baseline - 3) % 3dB down
                    % increment index and check power val
                    rightPwrIndex = rightPwrIndex+1; % increment by 1
                    rightPwr = pwrs(rightPwrIndex);
                    if ii>max_iter
                        break;
                    else
                        ii=ii+1;
                    end
                end
                
            else % is peak
                maxPwrIndex = find(self.fit.wvls==self.fit.peakWvl);
                maxPwr = pwrs(maxPwrIndex(end));
                
                % calculate Q = full width at half max
                leftPwr = maxPwr;
                leftPwrIndex = maxPwrIndex;
                rightPwr = maxPwr;
                rightPwrIndex = maxPwrIndex;
                % start at the top and go left
                ii = 0;
                while (leftPwr > maxPwr-3) % 3dB down
                    % decrement index and check power val
                    leftPwrIndex = leftPwrIndex-1; % decrement by 1
                    leftPwr = pwrs(leftPwrIndex);
                    if ii>max_iter
                        break;
                    else
                        ii=ii+1;
                    end
                end
                % go right
                ii=0;
                while (rightPwr > maxPwr-3) % 3dB down
                    % increment index and check power val
                    rightPwrIndex = rightPwrIndex+1; % increment by 1
                    rightPwr = pwrs(rightPwrIndex);
                    if ii>max_iter
                        break;
                    else
                        ii=ii+1;
                    end
                end
                baseline = maxPwr;
            end
            % find wavelengths at leftPwrIndex and rightPwrIndex
            self.fit.QMin3dBWvl = self.fit.wvls(leftPwrIndex);
            self.fit.QMax3dBWvl = self.fit.wvls(rightPwrIndex);
            self.fit.Q = self.fit.peakWvl/(self.fit.QMax3dBWvl-self.fit.QMin3dBWvl); % in um's
            self.fit.Qbaseline = baseline;
            
            if self.DEBUG
                disp('Calculating Q in PeakClass:');
                msg=strcat('QMin3dBWvl=',num2str(self.fit.QMin3dBWvl) );
                disp(msg);
                msg=strcat('QMax3dBWvl=',num2str(self.fit.QMax3dBWvl) );
                disp(msg);
                msg=strcat('Q =',num2str(self.fit.Q) );
                disp(msg);
                msg=strcat('Peak pwr =',num2str(maxPwr) );
                disp(msg);
            end
            
        end
        
        
        function [minus3dBWvl, plus3dBWvl, Q, baseline] = reportQ(self)
            disp('inside reportQ method');
            minus3dBWvl = self.fit.QMin3dBWvl;
            plus3dBWvl = self.fit.QMax3dBWvl;
            Q = self.fit.Q;
            baseline = self.fit.Qbaseline;
        end
    end % methods
    
    %%static methods
    methods (Static)
        %% calculateQ_static
        function Q = calculateQ_static(isPeak, wvls, pwrs)
            if ~isPeak % flip dataset
                pwrs = -pwrs;
            end
            [maxPwr, maxIndex] = max(pwrs); % find max pwr
            %            maxWvl = wvls(maxIndex); % find max wvl
            
            % calculate Q = full width at half max
            leftPwr = maxPwr;
            leftPwrIndex = maxIndex;
            rightPwr = maxPwr;
            rightPwrIndex = maxIndex;
            % start at the top and go left
            while (leftPwr > maxPwr-3) % 3dB down
                % decrement index and check power val
                leftPwrIndex = leftPwrIndex-1; % decrement by 1
                leftPwr = pwrs(leftPwrIndex);
            end
            % go right
            while (rightPwr > maxPwr-3) % 3dB down
                % increment index and check power val
                rightPwrIndex = rightPwrIndex+1; % increment by 1
                rightPwr = pwrs(rightPwrIndex);
            end
            % find wavelengths at leftPwrIndex and rightPwrIndex
            min3dBWvl = wvls(maxIndex+leftPwrIndex);
            max3dBWvl = wvls(maxIndex+rightPwrIndex);
            Q = 1.550/(max3dBWvl-min3dBWvl); % in um's
        end
    end
end