classdef appClass < handle
    % Summary of this class goes here
    %   Detailed explanation goes here
    
    % This class contains the methods used for the application. This class
    % instantiates the other classes (GUI, scanline, peak, etc.). It
    % acts as the 'controller' in the MVC architecture and manages the
    % coordination among the gui and models (scanline and peak classes).
    % Mostly, it is reponsible for
    %   1. Initializing the application -- loading user defaults
    %   2. Setting up the GUI
    %   3. mapping GUI callbacks to their respective class methods
    %      for example, a GUI callback for settings should be set to call a
    %      method directly in that class/object
    %
    % this class is also responsible for instantiating the scanClass (when
    % a dataset is loaded) and the peakClass (which is instantiated each
    % time a peak is selected).
    % shon's note -- not sure if selectPeaks should be a method in this
    % class or the scan class -- if the scan class, it should keep track of
    % the number of peaks selected but then there's the issue of managing
    % the gui windows. If it's managed from the appClass, handling the gui
    % might be easier.
    
    properties (Access = public)
        %% application properties
        menuBarFile; % options for main window menu buttons (pop-ups)
        menuBarChannel; % options for main window menu buttons (pop-ups)
        menuBarPeak; % options for main window menu buttons (pop-ups)
        contextMenu; % store values for context menu selections
        gui; % gui class object
        path; % path to dataset under analysis

        %% dataset specific application properties -- should be saved and re-loaded
        appParams;
        
        %% dataset properties -- raw data loaded from scan<x>.mat files
        dataset; % structure with all scan objects: dataset.{ch}(scanline)
        datasetParams; % parameters and info for the dataset (ie: number of scans, number of detectors, etc.)
        deviceInfo; % device under test (same for all scans/channels/peaks)
        firstScanNumber; % first scanline
        lastScanNumber; % last scanline loaded
        peakTrackingPlotCropValues; % (LB and UB) first and last scan #'s for cropping
        isPeak; % resonant peak vs. null
        reagentChangeIndex; % index into rawPeakTracking and fitPeakTracking of reagent changes
        scanTemperatures; % temp readings for each scaline
        scanTimes; % time stamps for each scanline
        testParams; % asay parameters for each scan (laser settings, etc.)
        timeStamp; % assay time stamp
        annotationText;
        annotationQText; %stores handle to Q label 
    end
    
    properties (Constant)
        DEBUG = false;
        LB = 1; % lower bound
        UB = 2; % upper bound
    end
    
    %% methods
    methods
        %% constructor
        function self = appClass (varargin)
            %% application properties
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % main menu bar config
            % file menu
            self.menuBarFile.foo1 = 'foo1';
            self.menuBarFile.foo2 = false;
            self.menuBarFile.foo3 = 3;
            % channel menu
            self.menuBarChannel.isPeak = false;
            self.menuBarChannel.correlationWindowSize = 2; % nm
            % peak menu
            self.menuBarPeak.normalizeCorrelation = false;
            self.menuBarPeak.reselectPeaksWindowSize = 4;
            self.menuBarPeak.refindPeakWindowSize = 2; % note fit window size is set to 1/2 * self.menuBarPeak.peakWindowSize
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % context menu options
            % default values for scanPlot
            self.contextMenu.scanPlot.showPrevious =  false;
            % default values for peakPlot
            self.contextMenu.peakPlot.addQ =  false;
            % default values for trackedPeaksPlot
            self.contextMenu.trackedPeaksPlot.normalize = false;
            self.contextMenu.trackedPeaksPlot.inPicoMeters = false;
            self.contextMenu.trackedPeaksPlot.plotRaw = false;
            self.contextMenu.trackedPeaksPlot.plotTemp = false;
            self.contextMenu.trackedPeaksPlot.reagentOffset = 0;
            self.contextMenu.trackedPeaksPlot.showReagents = false;
            self.contextMenu.trackedPeaksPlot.yDifferenceValues = [];
            self.contextMenu.trackedPeaksPlot.subtractReference = false;
            self.contextMenu.trackedPeaksPlot.showCurrentPosition = true;
            self.contextMenu.trackedPeaksPlot.plotExcludedScans = false;
                        
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % GUI class, open main window
            gui_figure_handle = guiMarking(); % draws gui returns handles
            self.gui = guidata(gui_figure_handle); % gui_figure_handle = 'handle to figure' self.gui is structure of all the handles associated w/ gui_figure_handle
            %self.gui = gui_figure_handle;
            
            % initialize dataset properties
            self.initializeDatasetProperties();
            
            %% more GUI -- context menus and callback mapping to class methods
            % setup figure context menus
            self.setupFigureContextMenus(gui_figure_handle); % pass GUI handle as parent
            % setup figure menus (use GUIDE tags)
            self.setupFigureMenuBar();
            
            % scan panel mapping to the class methods
            set(self.gui.panelScanExcludeCheckbox, 'callback',@self.panelScanExcludeCheckbox_callback);
            set(self.gui.panelScanReselectPeaksButton, 'callback',@self.panelScanReselectPeaksButton_callback);
            set(self.gui.panelScanChannelPopup, 'callback',@self.panelScanChannelPopup_callback);
            set(self.gui.panelScanEditScanInfoButton, 'callback',@self.panelScanEditScanInfoButton_callback);
            set(self.gui.panelScanScanNumberEdit, 'callback',@self.panelScanScanNumberEdit_callback);
            set(self.gui.panelScanTagPopup, 'callback',@self.panelScanTagPopup_callback);
            set(self.gui.panelScanNextButton, 'callback',{@self.panelScanPrevNextButton_callback, 1});
            set(self.gui.panelScanPrevButton, 'callback',{@self.panelScanPrevNextButton_callback, 0});
            
            % peak panel mapping to the class methods
            set(self.gui.panelPeakIsPeakCheckbox, 'callback',@self.panelPeakIsPeakCheckbox_callback);
            set(self.gui.panelPeakFitPeakButton, 'callback',@self.panelPeakFitPeakButton_callback);
            set(self.gui.panelPeakPopup, 'callback',@self.panelPeakPopup_callback);

            % peak tracking panel mapping to class methods
            set(self.gui.peakTrackingFigCropLB, 'callback', @self.peakTrackingFigCropLB_callback);
            set(self.gui.peakTrackingFigCropUB, 'callback', @self.peakTrackingFigCropUB_callback);
            
            % Slider bar mapping to class methods
            set(self.gui.panelMainSlider, 'Callback', @self.panelMainSlider_callback);
        end

        function self = initializeDatasetProperties(self)
            % shon put this in its own function so you can load a new
            % dataset without having to close the gui           
            % path
            self.path.datasetDir = ''; % user needs to manually load dataset
            self.path.analysisFile = ''; % user selects from list of previously saved analysis files
            
            %% (dataset-specific) APPLICATION properties (alphabetical)
            self.appParams.activeChannel = 1; % current channel index
            self.appParams.activePeak = 1; % current Peak Index
            self.appParams.activeScan = 1; % current scan index
            self.appParams.chopScans = 100; % number of scans to chop at end of array to avoid weird data spikes
            self.appParams.tempActiveChannelExcludedScans = []; % excluded scan number
            self.appParams.fitPeakTracking = {}; % array of fitted peak locations for each channel and peak
            self.appParams.rawPeakTracking = {}; % array of raw peak locations for each channel and peak
            self.appParams.referenceToSubract = ''; % 'channel\peak' to subtract from active peak tracking plot
            self.appParams.tag = 1; % index into channel tag list (default = functional)
            self.appParams.xData = {}; % used for peak track plotting: either scan # or time
            
            %% data specific properties
            self.dataset = {}; %scanline objects
            self.datasetParams = []; % struct for params common to all scans
            self.datasetParams.includedChannel = [];
%             self.datasetParams.numOfPeaks;
%             self.datasetParams.assayType;
            self.datasetParams.numOfChannels = 0;
%             self.datasetParams.numOfScans;
            self.firstScanNumber = 1; % changes after dataset loaded
            self.lastScanNumber = 1; % changes after dataset loaded
            self.isPeak; % resonant peak vs. null
            self.reagentChangeIndex = [];
            self.scanTemperatures = [];
            self.scanTimes = [];
%            self.testParams; % asay parameters for each scan (laser settings, etc.)
            self.timeStamp = 0; % assay time stamp
            self.annotationText = {};
        end
        
        function self = updateGUI(self)
            % scan panel mapping to the class methods
            set(self.gui.panelScanExcludeCheckbox, 'Value',...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.excludeScan);
            set(self.gui.panelScanChannelPopup, 'Value',self.appParams.activeChannel);
            set(self.gui.panelScanScanNumberEdit, 'Value',self.appParams.activeScan);
            set(self.gui.panelScanTagPopup, 'Value',self.appParams.tag(self.appParams.activeChannel));
            % peak panel mapping to the class methods
            set(self.gui.panelPeakIsPeakCheckbox, 'Value',...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.getIsPeak());
            % Slider bar mapping to class methods
            set(self.gui.panelMainSlider, 'Value', self.appParams.activeScan);
        end
        
        %% next button (duplicates main panel slider right button)
        function panelScanPrevNextButton_callback(self, ~, ~, dir)
            if dir
                set(self.gui.panelMainSlider, 'Value', self.appParams.activeScan+1);
            else
                set(self.gui.panelMainSlider, 'Value', self.appParams.activeScan-1);
            end
            % prep next frame (update gui, etc.)
            self.panelMainSlider_callback(self);
        end
        
        %% main panel slider (selects the active scanline)
        function panelMainSlider_callback(self, ~, ~)
            % check for first/last bounds
            % if left button clicked, increment self.appParams.activeScan by 1
            % if right button clicked, decrement self.appParams.activeScan by 1
            self.appParams.activeScan = round(get(self.gui.panelMainSlider, 'Value'));
            set(self.gui.panelScanScanNumberEdit, 'String', num2str(self.appParams.activeScan));
            % do prep next scan
            self.scanlineCorrelation();
            self.peaksCorrelation();
            self.updatePlotting();
            self.updateTable();
        end
        
        %% Dataset menu methods
%         % if no PeakTracking.mat file exists, auto analyze dataset
%         function self = menuDatasetPreprocess_callback (self, hObject, eventData)
%             % this should pop-up Vince's peak tracking tool and provide
%             % some initial guesses (or parameters) for automatically
%             % creating the PeakTracking.mat file
%         end
        
        %% context menu for figure windows
        function self = setupFigureContextMenus (self, gui_figure_handle)
            % context menu for tracked peaks figure
            % create context menu (not attached to anything)
            peakTrackingPlotContextMenu_h = uicontextmenu('Parent', gui_figure_handle);
            % install callbacks
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Hide position marker', 'Callback', @self.contextMenuTrackedPeaksPlotShowCurrentPosition);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Show excluded peaks', 'Callback', @self.contextMenuTrackedPeaksPlotPlotExcludedScans);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Units in pm', 'Callback', @self.contextMenuTrackedPeaksPlotShowInPm);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Show raw data', 'Callback', @self.contextMenuTrackedPeaksPlotShowRawTracking);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Normalize', 'Callback', @self.contextMenuTrackedPeaksPlotNormalize);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Subtract Reference', 'Callback', @self.contextMenuTrackedPeaksPlotSubtractReference);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Measure y-axis difference', 'Callback', @self.contextMenuTrackedPeaksPlotMeasureYDifference);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Add Vertical Marker', 'Callback', @self.contextMenuTrackedPeaksPlotAddLine);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Add Text', 'Callback', @self.contextMenuTrackedPeaksPlotAddText);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Remove Text', 'Callback', @self.contextMenuTrackedPeaksPlotRemoveText);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Plot Temp', 'Callback', @self.contextMenuTrackedPeaksPlotPlotTemp);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Show Reagents', 'Callback', @self.contextMenuTrackedPeaksPlotShowReagents);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Reagent Offset', 'Callback', @self.contextMenuTrackedPeaksPlotReagentOffset);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Export Data', 'Callback', @self.contextMenuTrackedPeaksPlotExportData);
            uimenu(peakTrackingPlotContextMenu_h, 'Label', 'Export Figure', 'Callback', {@self.contextMenuTrackedPeaksPlotUndock});
            % attach context menu to figure window
            set(self.gui.peakTrackingFig(1), 'uicontextmenu', peakTrackingPlotContextMenu_h);
                        
            % context menu for peak figure
            % create context menu (not attached to anything)
            peakPlotContextMenu_h = uicontextmenu('Parent', gui_figure_handle);
%            uimenu(peakPlotContextMenu_h, 'Label', 'Settings', 'Callback', @self.contextMenuPeakPlotFigSettings);
%            uimenu(peakPlotContextMenu_h, 'Label', 'Save', 'Callback', @self.contextMenuPeakPlotFigSave);
            uimenu(peakPlotContextMenu_h, 'Label', 'Add Q', 'Callback', @self.contextMenuPeakPlotAddQ);
            uimenu(peakPlotContextMenu_h, 'Label', 'Export Figure', 'Callback', {@self.contextMenuSinglePeakPlotUndock, self.gui.panelPeakThisPeakFig});
            % attach context menu to figure window
            set(self.gui.panelPeakThisPeakFig, 'uicontextmenu', peakPlotContextMenu_h);
            
            % context menu for scan figure
            % create context menu (not attached to anything)
            scanPeakContextMenu_h = uicontextmenu('Parent', gui_figure_handle);
%            uimenu(scanPeakContextMenu_h, 'Label', 'Settings', 'Callback', @self.contextMenuScanPlotSettings);
            uimenu(scanPeakContextMenu_h, 'Label', 'Show Previous', 'Callback', @self.contextMenuScanPlotAddPrevious);
            uimenu(scanPeakContextMenu_h, 'Label', 'Export Figure', 'Callback', {@self.contextMenuSinglePeakPlotUndock, self.gui.panelScanThisScanFig});
            % attach context menu to figure window
            set(self.gui.panelScanThisScanFig, 'uicontextmenu', scanPeakContextMenu_h);
        end
        
        % update values for context menus (for reloading previous settings from disk)
        function self = updateContextMenuValues(self)
            % peakPlot
            % scanPlot
            % peaksTrackingPlot
            if self.contextMenu.trackedPeaksPlot.subtractReference
                set(peakTrackingPlotContextMenu_h, 'Label', 'Undo Subtract Reference');
            else
                set(peakTrackingPlotContextMenu_h, 'Label', 'Subtract Reference');
            end
        end
        
        %% callback functions for context menus
        % tracked peaks figure context menu callbacks
        function self = contextMenuTrackedPeaksPlotSubtractReference (self, hObject, eventData)
            % set context menu label (toggle)
%            currentSetting = get(hObject, 'Label');
%            if strcmp(currentSetting, 'Subtract Reference') % subtract and toggle
            if ~self.contextMenu.trackedPeaksPlot.subtractReference % set, and subtract ref
                    % make a list of reference channels and peaks
                    referenceChList = {}; % empty cell array for ref list
                    % get cell array for tag
                    tagStr = get(self.gui.panelScanTagPopup, 'String');   % rtns cell array w/ all str values                 
                    for ch = self.datasetParams.includedChannel
                        if strcmp(tagStr{self.appParams.tag(ch)}, 'Reference')
                            for pp = 1:self.datasetParams.numOfPeaks(ch)
                                referenceChList{end+1} = strcat(num2str(ch), '.', num2str(pp));
                            end
                        end
                    end
                
                % quit if the user hasn't specified any reference channel
                if isempty(referenceChList) % no ref channel specified
                    msgbox('No reference channel specified');
                    return
                end
                % popup window for user to select refrence peak
                [selection, ok] = listdlg('Name', 'Reference Peaks', ...
                    'PromptString', 'Select the reference peak to subtract',...
                    'ListString', referenceChList,...
                    'SelectionMode', 'single');
                if ok
                    % set selection
                    % returns an index into cell array, get string value
                    self.appParams.referenceToSubract = referenceChList{selection};
                    % toggle
                    self.contextMenu.trackedPeaksPlot.subtractReference = true;
%                     h = get(self.gui.peakTrackingFig(1), 'uicontextmenu', peakTrackingPlotContextMenu_h);
%                     set(h, 'Label', 'Un-subtract Reference');
                    set(hObject, 'Label', 'Un-subtract Reference');
                end
            else % already subtracting reference channel ... clear subtraction and toggle
                self.appParams.referenceToSubract = ''; % clear 
                % toggle
                self.contextMenu.trackedPeaksPlot.subtractReference = false;
%                 h = get(self.gui.peakTrackingFig(1), 'uicontextmenu', peakTrackingPlotContextMenu_h);
%                 set(h, 'Label', 'Subtract Reference');
                set(hObject, 'Label', 'Subtract Reference');
            end
            % update plot with subtracted peak
            self.updatePlotting();
        end
        
        
        function self = contextMenuTrackedPeaksPlotMeasureYDifference (self, hObject, eventData)
            if isempty(self.contextMenu.trackedPeaksPlot.yDifferenceValues) % set, and add y-axis measurement
                % popup instructions window
                h = msgbox('Click on two points using the left-mouse button. The difference will be displayed on the plot. To start over, press the middle-mouse button.');
                uiwait(h);
                userClicks = 0;
                while userClicks < 2
                    % capture clicks
                    [x, y, button] = ginput(1); % identify 1 point and return L/middle/R button press
                    if (button == 2 || button == 3) % clear and reset
                        userClicks = 0;
                        self.contextMenu.trackedPeaksPlot.yDifferenceValues = [];
                    else % left button click (button == 1)
                        % assign y-values
                        userClicks = userClicks+1;
                        self.contextMenu.trackedPeaksPlot.yDifferenceValues.x(userClicks) = x;
                        self.contextMenu.trackedPeaksPlot.yDifferenceValues.y(userClicks) = y;
                    end
                end
                % add a dashed y-axis line at both y-axis points in the plotting function
                % add yDifference to plot -- self.contextMenu.trackedPeaksPlot.yDifferenceValues(end)-self.contextMenu.trackedPeaksPlot.yDifferenceValues(1)
                % toggle the context menu value
                set(hObject, 'Label', 'Remove y-axis difference measurement');
                % update plot
                self.updatePlotting();
            else % already displaying y-axis difference measurement ... clear and toggle context menu
                % clear
                self.contextMenu.trackedPeaksPlot.yDifferenceValues = [];
                set(hObject, 'Label', 'Measure y-axis difference');
                % update plot to remove y-axis lines
                self.updatePlotting();
            end
        end
        
        function self = contextMenuTrackedPeaksPlotAddLine (self, hObject, eventData)
            msgbox('contextMenuTrackedPeaksPlotAddLine -- shon needs to implement');
            return
        end
        
        function contextMenuTrackedPeaksPlotRemoveText (self, ~, ~)
            % popup annotation array and have user select which text to
            % remove
            [selection, ok] = listdlg(...
                'ListString', self.annotationText{:, 1},...
                'SelectionMode', 'single',...
                'Name', 'Remove plot text selection',...
                'PromptString', 'Select text item to remove from plot.');
            if ok
%                 for ii = selection:length(self.annotationText)
%                     % remove selection from array
%                     self.annotationText{ii} = self.annotationText{ii+1};
%                 end
%                 self.annotationText = [self.annotationText{1:selection-1} ...
%                     self.annotationText{selection+1:end}];
%                 if selection == 1
%                     self.annotationText = self.annotationText(2:end,:);
%                 elseif selection == length(self.annotationText(1, :))
%                     self.annotationText = self.annotationText(1:end - 1,:);
%                 else
%                     self.annotationText = [self.annotationText(1:selection-1,:);self.annotationText(selection+1:end,:)];
%                 end
            end
        end
        
        function contextMenuTrackedPeaksPlotAddText (self, ~, ~)            
            textStr = inputdlg(...
                {'Text:'} , ...
                'Add Text' , ...
                1, ...
                {''});
            % textStr = textStr{1};
            textStr = textwrap(textStr, 25);
            h = gtext(textStr', 'Fontsize', 10, 'Parent', self.gui.peakTrackingFig(1));
            
            self.annotationText{end+1, 1} = textStr;
            self.annotationText{end, 2} = get(h, 'Position');
        end
        
        function self = contextMenuTrackedPeaksPlotPlotTemp (self, hObject, eventData)
            self.contextMenu.trackedPeaksPlot.plotTemp = ~self.contextMenu.trackedPeaksPlot.plotTemp;
            if self.contextMenu.trackedPeaksPlot.plotTemp
                set(hObject, 'Label', 'Unplot Temp');
            else
                set(hObject, 'Label', 'Plot Temp');
            end
            self.plotPeakTracking();
        end
        
        function contextMenuTrackedPeaksPlotShowReagents(self, hObject, ~)
            self.contextMenu.trackedPeaksPlot.showReagents = ~self.contextMenu.trackedPeaksPlot.showReagents;
            if self.contextMenu.trackedPeaksPlot.showReagents
                self.showReagents();
                self.plotPeakTracking();
                set(hObject, 'Label', 'Hide Reagents');
            else
                self.plotPeakTracking();
                set(hObject, 'Label', 'Show Reagents');
            end
        end
        
        function contextMenuTrackedPeaksPlotReagentOffset(self, ~, ~)
            prompt = {'Enter the Reagent Change Offset'};
            name = 'User Input';
            numlines = 1;
            defaultanswer = {num2str(self.contextMenu.trackedPeaksPlot.reagentOffset)};
            self.contextMenu.trackedPeaksPlot.reagentOffset = str2double(inputdlg(prompt, name, numlines, defaultanswer));
            self.plotPeakTracking();
        end
        
        function contextMenuTrackedPeaksPlotShowCurrentPosition(self, hObject, ~)
            self.contextMenu.trackedPeaksPlot.showCurrentPosition = ~self.contextMenu.trackedPeaksPlot.showCurrentPosition;
            if self.contextMenu.trackedPeaksPlot.showCurrentPosition
                set(hObject, 'Label', 'Hide position marker');
            else
                set(hObject, 'Label', 'Show position marker');
            end
            self.plotPeakTracking();
        end
        
        function contextMenuTrackedPeaksPlotPlotExcludedScans(self, hObject, ~)
            self.contextMenu.trackedPeaksPlot.plotExcludedScans = ~self.contextMenu.trackedPeaksPlot.plotExcludedScans;
            if self.contextMenu.trackedPeaksPlot.plotExcludedScans
                set(hObject, 'Label', 'Hide excluded peaks');
            else
                set(hObject, 'Label', 'Show excluded peaks');
            end
            self.plotPeakTracking();
        end
        
        function contextMenuTrackedPeaksPlotShowInPm(self, hObject, ~)
            self.contextMenu.trackedPeaksPlot.inPicoMeters = ~self.contextMenu.trackedPeaksPlot.inPicoMeters;
            if self.contextMenu.trackedPeaksPlot.inPicoMeters
                set(hObject, 'Label', 'Units in nm');
            else
                set(hObject, 'Label', 'Units in pm');
            end
            self.plotPeakTracking();
        end
                
        function contextMenuTrackedPeaksPlotShowRawTracking(self, hObject, ~)
            self.contextMenu.trackedPeaksPlot.plotRaw = ~self.contextMenu.trackedPeaksPlot.plotRaw;
            if self.contextMenu.trackedPeaksPlot.plotRaw
                set(hObject, 'Label', 'Hide raw data');
            else
                set(hObject, 'Label', 'Show raw data');
            end
            self.plotPeakTracking();
        end
                
        function contextMenuTrackedPeaksPlotNormalize(self, hObject, ~)
            self.contextMenu.trackedPeaksPlot.normalize = ~self.contextMenu.trackedPeaksPlot.normalize;
            if self.contextMenu.trackedPeaksPlot.normalize
                set(hObject, 'Label', 'Un-Normalize');
            else
                set(hObject, 'Label', 'Normalize');
            end
            self.plotPeakTracking();
        end
        
        function contextMenuTrackedPeaksPlotExportData(self, ~, ~)
            defaultFileName = sprintf('%s_PeakTracking_Channel%d_%s.mat', self.deviceInfo.Name, self.appParams.activeChannel, datestr(now, 'yyyy.mm.dd@HH.MM'));
            [fileName, pathName] = uiputfile([self.path.datasetDir, defaultFileName], 'Export PeakTracking Data');
            if isequal(fileName, 0) || isequal(pathName,0)
                return;
            end
            tempRawPeakTrackingArray = struct(...
                'peakRawTracking', self.appParams.rawPeakTracking{self.appParams.activeChannel}{self.appParams.activePeak}, ...
                'time', self.scanTimes, ...
                'temp', self.scanTemperatures);
            save([pathName, fileName], '-struct', 'tempRawPeakTrackingArray');
        end
        
        function contextMenuTrackedPeaksPlotUndock(self, hObject, eventData)
            undockPeakTrackFigure = figure(...
                'Unit', 'normalized', ...
                'Position', [0, 0, 0.50, 0.50],...
                'Name', 'Peak Tracking Figure',...
                'NumberTitle', 'off');
            movegui(undockPeakTrackFigure, 'center');
            % size(self.gui.peakTrackingAndTempFig) 
%             axes_h = get(get(figureHandle,'Parent'),'Children');
            %            undockPeakTrackAxes = copyobj(self.gui.peakTrackingFig(1), undockPeakTrackFigure);
            undockPeakTrackAxes = copyobj(self.gui.peakTrackingAndTempFig, undockPeakTrackFigure);
            set(undockPeakTrackAxes, 'Units', 'Normalized', 'Position', [0.1, 0.1, 0.8, 0.85]);
        end
        
        
        function contextMenuSinglePeakPlotUndock(self, hObject, eventData, figureHandle)
            undockPeakTrackFigure = figure(...
                'Unit', 'normalized', ...
                'Position', [0, 0, 0.50, 0.50],...
                'Name', 'Peak Tracking Figure',...
                'NumberTitle', 'off');
            movegui(undockPeakTrackFigure, 'center');
            undockPeakTrackAxes = copyobj(figureHandle, undockPeakTrackFigure);
            set(undockPeakTrackAxes, 'Units', 'Normalized', 'Position', [0.1, 0.1, 0.8, 0.85]);
        end        
        
        
        % peaks figure context menu callbacks
        function self = contextMenuPeakPlotFigSettings (self, hObject, eventData)
            msgbox('contextMenuPeakPlotFigSettings -- shon needs to implement');
            return
        end
%         function self = contextMenuPeakPlotFigSave (self, hObject, eventData)
%             msgbox('contextMenuPeakPlotFigSave -- shon needs to implement');
%             return
%         end
        function self = contextMenuPeakPlotAddQ (self, hObject, eventData)
            self.contextMenu.peakPlot.addQ = ~self.contextMenu.peakPlot.addQ;
            if self.contextMenu.peakPlot.addQ
                set(hObject, 'Label', 'Remove Q');                
            else
                set(hObject, 'Label', 'Add Q');                
            end
            self.updatePlotting(); 
        end
        
        % scan figure context menu callbacks
        function self = contextMenuScanPlotSettings (self, hObject, eventData)
            msgbox('contextMenuScanPlotSettings -- shon needs to implement');
            return
        end
        function self = contextMenuScanPlotSave (self, hObject, eventData)
            msgbox('contextMenuScanPlotSave -- shon needs to implement');
            return
        end
        function self = contextMenuScanPlotAddPrevious (self, hObject, ~)
            % not valid on first scan
            if self.appParams.activeScan > self.firstScanNumber
                % toggle if user selects
                self.contextMenu.scanPlot.showPrevious = ~self.contextMenu.scanPlot.showPrevious;
                % update string in context menu
                if self.contextMenu.scanPlot.showPrevious
                    set(hObject, 'Label', 'Hide Previous');
                else
                    set(hObject, 'Label', 'Show Previous');
                end
                self.plotPeakTracking();
            end
            % update plots
            self.updatePlotting();
        end
        
        %% callbacks for scan panel
%         % channel tag
%         function self = panelScanTagPopup_callback(self, hObject, eventData)
%             list = get(hObject, 'String'); % cell array of possible selections
%             chosen = get(hObject, 'Value'); % index into what was selected
%             self.appParams.tag = list{chosen};
%         end
        
        % exclude scan from dataset
        function self = panelScanExcludeCheckbox_callback (self, hObject, ~)
            % get checkbox value, toggle and set in scanClass
            for channel = self.datasetParams.includedChannel
                self.dataset{channel, self.appParams.activeScan}.excludeScan = get(hObject, 'Value');
            end
            if self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.excludeScan
                if ~any(self.appParams.activeScan == self.appParams.tempActiveChannelExcludedScans)
                    self.appParams.tempActiveChannelExcludedScans = sort([self.appParams.tempActiveChannelExcludedScans, self.appParams.activeScan]);
                end
            else
                removeIndex = find(self.appParams.activeScan == self.appParams.tempActiveChannelExcludedScans);
                if removeIndex == 1
                    self.appParams.tempActiveChannelExcludedScans = self.appParams.tempActiveChannelExcludedScans(2:end);
                elseif removeIndex == length(self.appParams.tempActiveChannelExcludedScans)
                    self.appParams.tempActiveChannelExcludedScans = self.appParams.tempActiveChannelExcludedScans(1:end-1);
                else
                    self.appParams.tempActiveChannelExcludedScans = [self.appParams.tempActiveChannelExcludedScans(1:removeIndex - 1), self.appParams.tempActiveChannelExcludedScans(removeIndex + 1, end)];
                end
            end
            self.plotPeakTracking();
        end
        
        function updateScanExclusionData(self)
            if self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.excludeScan
                self.appParams.tempActiveChannelExcludedScans = sort([self.appParams.tempActiveChannelExcludedScans, self.appParams.activeScan]);
                for pp = 1:self.datasetParams.numOfPeaks(self.appParams.activeChannel)
                    if self.appParams.activeScan == self.firstScanNumber
                        self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan) = self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan + 1);
%                        self.appParams.rawPeakTrackingN{self.appParams.activeChannel}{pp} = self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp} - self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(1);
                    elseif self.appParams.activeScan == self.lastScanNumber
                        self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan) = self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan - 1);
%                        self.appParams.rawPeakTrackingN{self.appParams.activeChannel}{pp}(self.appParams.activeScan) = self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan) - self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(1);
                    else
                        %note jonasf: this only works well for single
                        %exclusion also check if previousX is excluded or
                        %not
                        
                        previousX = self.appParams.xData(self.appParams.activeScan - 1);
                        nextX = self.appParams.xData(self.appParams.activeScan + 1);
                        previousPeak = self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan - 1);
                        nextPeak = self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan + 1);
                        
                        %look for closest included scan line
                        ee = 1 ;
                        while (self.dataset{self.appParams.activeChannel, self.appParams.activeScan-ee}.excludeScan && ee<10)
                            previousX = self.appParams.xData(self.appParams.activeScan - ee);
                            previousPeak = self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan - ee);
                            ee=ee+1;
                            disp('previous peak');
                        end
                        ee = 1 ;
                        while (self.dataset{self.appParams.activeChannel, self.appParams.activeScan+ee}.excludeScan && ee<10)
                            nextX = self.appParams.xData(self.appParams.activeScan + ee);
                            nextPeak = self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan + ee);
                            ee=ee+1 ;
                            disp('next peak');
                        end
                        
                        fitP = polyfit([previousX, nextX], [previousPeak, nextPeak], 1);
                        self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan) = polyval(fitP, self.appParams.xData(self.appParams.activeScan));
%                        self.appParams.rawPeakTrackingN{self.appParams.activeChannel}{pp}(self.appParams.activeScan) = self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan) - self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(1);
                    end
                end
            else % Include this scan back
                for pp = 1:self.datasetParams.numOfPeaks(self.appParams.activeChannel)
                    self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(self.appParams.activeScan) = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{pp}.raw.peakWvl;
%                    self.appParams.rawPeakTrackingN{self.appParams.activeChannel}{pp}(self.appParams.activeScan) = self.appParams.rawPeakTrackingN{self.appParams.activeChannel}{pp}(self.appParams.activeScan) - self.appParams.rawPeakTracking{self.appParams.activeChannel}{pp}(1);
                end
            end
        end
        
        % select new peaks
        function self = panelScanReselectPeaksButton_callback(self, hObject, eventData)
            axes(self.gui.panelScanThisScanFig);
            [selWvl, selPwr, button] = ginput(1);
            if button == 1
                %get old peak wvl

                initWvl = self.dataset{self.appParams.activeChannel,self.appParams.activeScan}.peaks{self.appParams.activePeak}.getFitProp('peakWvl');

                refineWindowSize = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.reselectPeak(self.appParams.activePeak,...
                                                selWvl, selPwr,...
                                                self.menuBarPeak.reselectPeaksWindowSize);  %reselect with popup window
                refineWvl = self.dataset{self.appParams.activeChannel,self.appParams.activeScan}.peaks{self.appParams.activePeak}.getFitProp('peakWvl');
                self.appParams.peakTracking{self.appParams.activeChannel}{self.appParams.activePeak}(self.appParams.activeScan) = refineWvl;

                if self.DEBUG
                   msg=strcat('Reselect peak => initWvl = ', num2str(initWvl));
                   disp(msg);
                   msg=strcat('Reselect peak => NewWvl = ', num2str(refineWvl)); 
                   disp(msg);
                end
                
                choice = questdlg('Do you want to apply the change to the remaining scans?', ...
                    'Reselect Peak Shifting', ...
                    'Yes', 'No', 'Yes');
                if strcmpi(choice, 'Yes')
                    waitbar_handle = waitbar(0, 'Updating peak fit for rest of dataset...');
                    
                    for scanNum = self.appParams.activeScan + 1:self.lastScanNumber
                        if ~self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.getFitProp('reviewed');  % was manually checked.
                            self.dataset{self.appParams.activeChannel, scanNum}.refindPeak(self.appParams.activePeak,...
                                refineWvl,...
                                refineWindowSize);
                            refineWvl = self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.peakWvl;
                            self.appParams.peakTracking{self.appParams.activeChannel}{self.appParams.activePeak}(scanNum) = ...
                                self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.getFitProp('peakWvl');
                        end
                        waitbar(scanNum/self.lastScanNumber, waitbar_handle, sprintf('Updating: %d%%', round(100*scanNum/self.lastScanNumber)));
                    end
                    delete(waitbar_handle);
                end
                
                self.updatePlotting();
            end
        end
        
        % select a different channel
        function self = panelScanChannelPopup_callback (self, hObject, eventData)
            channels = get(hObject, 'String');
            channelSelection = get(hObject, 'Value');
            self.appParams.activeChannel = str2double(channels{channelSelection});
            set(self.gui.panelPeakPopup, 'String', num2cell(1:self.datasetParams.numOfPeaks(self.appParams.activeChannel)));
            self.appParams.activePeak = 1;
            set(self.gui.panelPeakPopup, 'Value', self.appParams.activePeak);
            % set channel tag
            % self.appParams.tag(self.appParams.activeChannel) is the index into (self.gui.panelScanTagPopup, 'String', {'Functional', 'Reference', 'Acetylene Cell'});
%            tagList = get(self.gui.panelScanTagPopup, 'String');
            set(self.gui.panelScanTagPopup, 'Value', self.appParams.tag(self.appParams.activeChannel));
            self.updatePlotting();
        end
        
        % select tag for channel (eg: reference, functional, etc.)
        function self = panelScanTagPopup_callback (self, hObject, eventData)
            % set active channel's tag
            self.appParams.tag(self.appParams.activeChannel) = get(hObject, 'Value');
        end
        
        % edit scan info (eg: reagents, etc.)
        function self = panelScanEditScanInfoButton_callback (self, hObject, eventData)
            % the user can edit scan info for the scanline (eg: reagent, etc.)
            % TODO: shons note to self -- need to fix this. perhaps the
            % code returns the updated params that the method writes back
            % to class obj?
            settingsPopup(self, 'dataset{self.appParams.activeChannel, self.appParams.activeScan}.AssayParams');
        end
        
        % edit scan number
        function panelScanScanNumberEdit_callback (self, hObject, ~)
            scanNum = str2double(get(hObject, 'String'));
            if scanNum >= self.firstScanNumber && scanNum <= self.lastScanNumber
                set(self.gui.panelMainSlider, 'Value', scanNum);
                self.panelMainSlider_callback(self.gui.panelMainSlider, [])
            end
        end
        
        %% callbacks for peak panel
        % use fit in peak tracking analysis
        function self = panelPeakUseFitCheckbox_callback (self, hObject, eventData)
            useFit = get(hObject, 'Value');
            %uses fits to plot; note jonasf: stored in peak so we can
            %choose for each channel AND for each peak. 
            for scanNum = self.firstScanNumber:self.lastScanNumber
                self.dataset{self.appParams.activeChannel, scanNum}.peaks{self.appParams.activePeak}.useFit = useFit;
            end
        end
        
        % specify if it is a peak or a resonant null
        function self = panelPeakIsPeakCheckbox_callback(self, hObject, eventData)
            val = get(hObject, 'Value');
            self.isPeak{self.appParams.activeChannel}(self.appParams.activePeak) = val;
            for scanNum = self.firstScanNumber:self.lastScanNumber
                self.dataset{self.appParams.activeChannel, scanNum}.isPeak(self.appParams.activePeak) = val;
                self.dataset{self.appParams.activeChannel, scanNum}.peaks{self.appParams.activePeak}.setIsPeak(val);
            end
        end
        
        % peak fitting
        % 21 Nov 2014 shon
        function self = panelPeakFitPeakButton_callback(self, hObject, eventData)
            self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.openPeakFitWindow();
                     uiwait   
            %added to initialize tempFitPeakTracking matrix if []
            if isempty(self.appParams.fitPeakTracking{self.appParams.activeChannel})  %if there is no peaks
                errordlg('fitPeakTracking is empty, this should not be the case');
            end
            choice = questdlg('Do you want to apply the same peak fitting settings to the remaining scans?', ...
                'Peak Fitting', ...
                'Yes', 'No', 'Yes'); 
            if strcmpi(choice,'Yes')
                waitbar_handle = waitbar(0, 'Updating peak fit for rest of dataset...');
                % grab the fit window size from *this* scan and apply to subsequent scans
                %self.fit.params.windowSize
%                fitWindowSize = self.dataset{self.appParams.activeChannel,self.appParams.activeScan}.peaks{self.appParams.activePeak}.getFitParam('windowSize');
                [fitType, fitParams] = self.dataset{self.appParams.activeChannel,self.appParams.activeScan}.peaks{self.appParams.activePeak}.getFitParams();
                % loop through the rest of teh scans
                userResponse = ''; % for debug
                for scanNum = self.appParams.activeScan + 1:self.lastScanNumber
                    if ~self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.getFitProp('reviewed');  % was manually checked. 
%                        previous_type = self.dataset{self.appParams.activeChannel,scanNum-1}.peaks{self.appParams.activePeak}.getFitProp('type');
%                        self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.setFitType(previous_type);
%                        self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.fitPeak;
                        % set new window size
%                        self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.setFitParam('windowSize', fitWindowSize);
                        self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.setFitParams(fitType, fitParams);
                        % initialize new window bounds
%                        self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.initializeFitWindowBounds();                        
                        % do fit w/ new params
%                        self.dataset{self.appParams.activeChannel,scanNum}.peaks{self.appParams.activePeak}.fitPeak();
                        if self.DEBUG
                            msg = strcat(...
                                '::scan=',num2str(scanNum),...
                                '::ch=',num2str(self.appParams.activeChannel),...
                                '::pk=',num2str(self.appParams.activePeak),...
                                '::fitType=',fitType,...
                                '::fitParams.windowSize',num2str(fitParams.windowSize));
                            disp(msg);
                            if ~strcmp(userResponse,'c') % continue to end
                                userResponse = input('In peak class setFitParam::Continue? [<CR> -or- c to continuous] = ','s'); % returns as string
                            end                        
                        end
                    end
                    waitbar(scanNum/self.lastScanNumber, waitbar_handle, sprintf('Updating: %d%%', round(100*scanNum/self.lastScanNumber)));
                end
                delete(waitbar_handle);
                
                self.createPeakTracking(); 
                self.updatePlotting();
            else
               %should add something here. 
               
               self.updatePlotting();
            end
            
        end
        
        % select a different peak to analyze
        function self = panelPeakPopup_callback (self, hObject, ~)
            self.appParams.activePeak = get(hObject, 'Value');
            self.updatePlotting();
        end
        
        % crop the peak tracking plot
        function self = peakTrackingFigCropLB_callback (self, hObject, ~)
            numStr = get(hObject, 'String');
            self.peakTrackingPlotCropValues(self.LB) = str2num(numStr);
            self.updatePlotting();
        end
        
        function self = peakTrackingFigCropUB_callback (self, hObject, ~)
            numStr = get(hObject, 'String');
            self.peakTrackingPlotCropValues(self.UB) = str2num(numStr);
            self.updatePlotting();
        end
        
        %% main figure menu bar callbacks
        function self = setupFigureMenuBar (self)
            % menu
            set(self.gui.menuBarFilePreferences, 'Callback', @self.mainMenuFilePreferences);
            set(self.gui.menuBarFileRefreshScriptMenu, 'Callback', @self.populateAnalysisScriptMenu);
            set(self.gui.menuBarFileQuit, 'Callback', @self.mainMenuFileQuit);
            
            % dataset
            set(self.gui.menuBarDatasetLoad, 'Callback', @self.mainMenuLoadDataset_Callback);
            set(self.gui.menuBarDatasetSaveAnalysis, 'Callback', @self.mainMenuDatasetSaveAnalysis_Callback);
            set(self.gui.menuBarDatasetClose, 'Callback', @self.mainMenuDatasetClose_Callback);
            set(self.gui.menuBarDatasetPreprocess, 'Callback', @self.mainMenuDatasetPreprocess_Callback);
% shon removed 28 nov 2014            set(self.gui.menuBarDatasetReportQs, 'Callback', @self.mainMenuDatasetReportQs_Callback);
            
            % channel
            set(self.gui.menuBarChannelPreferences, 'Callback', @self.menuBarChannelPreferences_Callback);
            
            % peak
            set(self.gui.menuBarPeakPreferences, 'Callback', @self.menuBarPeakPreferences_Callback);
            
            % analysis scripts
            self.populateAnalysisScriptMenu();
        end
        
        function self = populateAnalysisScriptMenu (self, ~, ~) % ~ = hObject and eventData
            % clear uimenu label (or current list of scripts)
            allChildrenHandles = get(self.gui.menuBarAnalysisScripts, 'Children');
            delete(allChildrenHandles); % but handles stay in workspace (although deleted from gui)
            % create ui menu and populate for analysis scripts
            % get a list of analysisScripts dir contents
            listOfUserAnalysisScripts = dir('analysisScripts/*.m');
            if ~isempty(listOfUserAnalysisScripts) % enable menu
                set(self.gui.menuBarAnalysisScripts, 'Enable', 'on'); % for debug only...
            end
            % ignore . and .. in list, hence 3 onward ... build menu
            for ii = 1:length(listOfUserAnalysisScripts)
                uimenu(self.gui.menuBarAnalysisScripts, 'Label', listOfUserAnalysisScripts(ii).name(1:end-2), 'Callback', {@self.menuBarAnalysisScripts_Callback, listOfUserAnalysisScripts(ii).name(1:end-2)});
            end            
        end
        
        %% callbacks for main figure menubar
        function self = mainMenuFilePreferences (self, hObject, eventData)
            self.settingsPopup('menuBarFile');
        end

        function self = mainMenuFileRefreshScriptMenu (self, hObject, eventData)
            self.populateAnalysisScriptMenu();
        end
        
        function self = mainMenuFileQuit (self, hObject, eventData)
            % close window
%             mainWinH = get(self.gui.panelMainDatasetPathString, 'Parent');
%             close(mainWinH);
            delete(gcf);
            % delete all data and objects
            clear all;
            clc;
        end
        
        %% load dataset
        function self = mainMenuLoadDataset_Callback (self, ~, eventData)
            self.path.datasetDir = uigetdir(self.path.datasetDir, 'Dataset folder');
            % return if user cancelled
            if self.path.datasetDir == 0 %user pressed cancel
                return
            end
            % check for '\' at end, append
            if ~strcmpi (self.path.datasetDir(end), '\')
                self.path.datasetDir = strcat(self.path.datasetDir, '\');
            end;
            % write path name to GUI
            set(self.gui.panelMainDatasetPathString, 'String', self.path.datasetDir);
            % load raw data from Scan<x>.mat files
            self.loadRawDataFromScanFiles();
            % load peak tracking data
% shon 28 nov 2014 - superceded by scanFileData.peakResults addition in big setup
%             filename = strcat(self.path.datasetDir, 'PeakTracking.mat');
%             if exist(filename, 'file') % load
%                 self.loadPeakTrackingData();
%             else % have user select peak on the fly
%                 self.preProcessDataset();
%             end
            % load previous analysis
            if ~strcmp(self.path.datasetDir(end), '\')
                self.path.datasetDir = strcat(self.path.datasetDir,'\');
            end
            wildCard = strcat(self.path.datasetDir, '_Analysis_*.mat');
            dirList = dir(wildCard);
            if ~isempty(dirList) % create a new analysis file
                files = {dirList.name};
                % popup list and allow user to select previous or create new
                [selection,ok] = listdlg(...
                    'ListString', files,...
                    'SelectionMode', 'single',...
                    'Name', 'Analysis Files',...
                    'PromptString','Load previous analysis. Cancel to create new.');
                if ok
                    fn = files{selection};
                    self.loadAnalysis(fn); % load analysis
                end
            end
            % create file w/ time stamp for saving analysis this time (regardless of what's loaded)
            self.setAnalysisFile(); % create new

            % Finish up -- set GUI elements
            set(self.gui.panelMainFirstScanString, 'String', self.firstScanNumber);
            set(self.gui.panelMainLastScanString, 'String', self.lastScanNumber);
            set(self.gui.panelMainSlider, 'Min', self.firstScanNumber);
            set(self.gui.panelMainSlider, 'Max', self.lastScanNumber);
            set(self.gui.panelMainSlider, 'SliderStep', [1, 1]/(self.datasetParams.numOfScans - 1));
            set(self.gui.panelMainSlider, 'Value', self.appParams.activeScan);
            set(self.gui.panelScanChannelPopup, 'String', num2cell(self.datasetParams.includedChannel))
            self.appParams.activeChannel = self.datasetParams.includedChannel(1);
            set(self.gui.panelScanChannelPopup, 'Value', 1);
            set(self.gui.panelPeakPopup, 'String', num2cell(1:self.datasetParams.numOfPeaks(self.appParams.activeChannel)));
            set(self.gui.panelPeakPopup, 'Value', self.appParams.activePeak);
            
            % Plotting
            self.createTimeAndscanTemperatures();
            self.createPeakTracking();
            
            if self.testParams.AssayParams.TranslateRecipeTimeToSweeps
                self.appParams.xData = self.firstScanNumber:self.lastScanNumber;
            else
                self.appParams.xData = self.scanTimes;
            end
            set(self.gui.panelScanScanNumberEdit, 'String', '1');
            self.updatePlotting();
            self.updateTable();
            
            % enable other menus
            set(self.gui.menuBarChannel, 'Enable', 'on');
            set(self.gui.menuBarPeak, 'Enable', 'on');
            set(self.gui.menuBarAnalysisScripts, 'Enable', 'on');
            
            %% configure gui elements
            % tag popup config
            set(self.gui.panelScanTagPopup, 'String', {'Functional', 'Reference', 'Acetylene Cell'});
%            set(self.gui.panelScanTagPopup, 'Value', self.scanDataTagOptions{1}); % default value            
            % enable save button
            set(self.gui.menuBarDatasetSaveAnalysis, 'Enable', 'on'); % enable analysis saving
        end
        
        %% load raw data from Scan<x>.mat files
        function self = loadRawDataFromScanFiles (self)
            % Load raw data from Scan<x>.mat files
            % check how many scan files exist
            fileType = strcat(self.path.datasetDir, 'Scan*.mat');
            list = dir(fileType);
            % determine how many scan files are in the directory
            self.lastScanNumber = length(list);
            % update GUI cropping feature
            self.peakTrackingPlotCropValues(self.LB) = self.firstScanNumber;
            self.peakTrackingPlotCropValues(self.UB) = self.lastScanNumber;
            set(self.gui.peakTrackingFigCropLB, 'String', ...
                num2str(self.peakTrackingPlotCropValues(self.LB)));
            set(self.gui.peakTrackingFigCropUB, 'String', ...
                num2str(self.peakTrackingPlotCropValues(self.UB)));
            
            % determine starting scan, assume first scan file = Scan1.mat
            self.firstScanNumber = 1;
            % create filename
            filename = strcat(self.path.datasetDir, 'Scan', num2str(self.firstScanNumber), '.mat');
            while ~exist(filename, 'file')
                msg = strcat('File ', filename, ' does not exist. ');
                self.firstScanNumber = self.firstScanNumber + 1;
                filename = strcat(self.path.datasetDir, 'Scan', num2str(self.firstScanNumber), '.mat');
                msg = strcat(msg, 'Checking for file ', filename);
                disp(msg);
            end
            % Initialize variables
            self.reagentChangeIndex = [];
            previousReagent = '';
            previousFlowRate = ''; % sometimes reagents are same but flow rate changes
            % create waitbar
            waitbar_handle = waitbar(0, 'Loading Scan<x>.mat data...');
            for scanNumber = self.firstScanNumber:self.lastScanNumber
                filename = strcat(self.path.datasetDir, 'Scan', num2str(scanNumber), '.mat');
                if ~exist(filename, 'file')
                    waitbar(scanNumber/self.lastScanNumber, waitbar_handle, sprintf('Scan#%d: File Missing!', scanNumber));
                else % Scan File Exist
                    waitbar(scanNumber/self.lastScanNumber, waitbar_handle, sprintf('Loading: %d%%', round(100*scanNumber/self.lastScanNumber)));
                    scanFileData = load(filename);
                    % parameters common to every scanline in the dataset
                    if scanNumber == self.firstScanNumber
                        % check for compatibility w/ latest TB code
                        list = fieldnames(scanFileData);
%                        if ~isStruct(scanFileData.peakResults)
                        if ~strcmp(list, 'peakResults')
                            h=msgbox('peakResults does not exist in the scan file. Must preprocess dataset.');
                            uiwait(h); 
                            % preprocess dataset
                            self.preProcessDataset();
                            % reload first file w/ compatible structs
                            scanFileData = load(filename);
                        end
                        self.testParams = scanFileData.params;
                        self.deviceInfo = scanFileData.deviceInfo;
                        self.datasetParams.numOfScans = self.lastScanNumber - self.firstScanNumber + 1;
                        self.datasetParams.assayType = '';
                        [~, self.datasetParams.numOfChannels] = size(scanFileData.scanResults);
                        % Determine channel and peaks information
                        self.datasetParams.includedChannel = []; % initialize to 0, incase it's written by preProcessDataset
                        for ch = 1:self.datasetParams.numOfChannels
                            if ~scanFileData.scanResults(1,ch).Data(1,1) == 0 % check in first wvl value is 0
                                self.datasetParams.includedChannel(end + 1) = ch;
                            end
                        end                        
                        % initialize cell array to store scanline objects
                        self.dataset = cell(self.datasetParams.numOfChannels, self.datasetParams.numOfScans);
                        % isPeak this as well? self.isPeak{ch}(pp) shon 28 nov 2014
                    end %if firstScanNumber
                    % initialize default values (can be overwritten by previous analysis that's loaded later)                   
                    self.dataset{self.appParams.activeChannel, scanNumber}.excludeScan = false;                    
                    % Create Scanline Objects for each detector channel
                    
                    for channel = self.datasetParams.includedChannel % number of channels
                        % peaks -- new code by shon 28 nov 2014 to supercede PeaksTracking.mat file w/ scanFileData.peakResults...
                        self.isPeak = scanFileData.peakResults.isPeak;
                        self.datasetParams.numOfPeaks(channel) = length(scanFileData.peakResults.peakWvl{channel});

                        % create peak location
                        self.datasetParams.numOfPeaks(channel) = ...
                            length(scanFileData.peakResults.peakWvl{channel});
                        for peak = 1:self.datasetParams.numOfPeaks(channel)
                            peakLocation(peak) = scanFileData.peakResults.peakWvl{channel}{peak};
                        end                        
                        % defaults for peak object creation

                        allPeaksInfo = struct(...
                            'isPeak', self.isPeak(channel), ...
                            'numOfPeaks', length(scanFileData.peakResults.peakWvl{channel}), ...
                            'peakLocation', peakLocation);

                        tempWvl = scanFileData.scanResults(channel).Data(:,1);
                        tempPwr = scanFileData.scanResults(channel).Data(:,2);
                        % create scan object
                        self.dataset{channel, scanNumber} = scanClass(...
                            tempWvl(self.appParams.chopScans:end-self.appParams.chopScans),...
                            tempPwr(self.appParams.chopScans:end-self.appParams.chopScans),...
                            scanFileData.params, ...
                            scanFileData.timeStamp, ...
                            allPeaksInfo,...
                            scanFileData.peakResults.wvlWindow{channel}); % create object
                        self.dataset{channel,scanNumber}.DEBUG = self.DEBUG; 
                        % create peak object
                        self.dataset{channel, scanNumber}.createPeakObject();
                        % set default tag value
                        self.appParams.tag(channel) = 1; % set to functional tag
                        % create rawPeakTracking - not sure we need to do this - shon
                        self.datasetParams.numOfPeaks(channel) = ...
                            length(scanFileData.peakResults.peakWvl{channel});
                        for peak = 1:self.datasetParams.numOfPeaks(channel)
                            self.appParams.rawPeakTracking{channel}{peak}(scanNumber) = ...
                                scanFileData.peakResults.peakWvl{channel}{peak};
                        end                        
                        % parameters for this scanline
%                        self.dataset{channel, scannumber}.params = scanfiledata.params;
%                        self.dataset{channel, scannumber}.timestamp = scanfiledata.timestamp;
                        % Check for reagent change and record scan #
                        if ~strcmpi(self.dataset{channel, scanNumber}.params.ReagentName, previousReagent) || ...
                                self.dataset{channel, scanNumber}.params.FlowRate ~= previousFlowRate
                            self.reagentChangeIndex(end + 1) = scanNumber;
                        end
                        previousReagent = self.dataset{channel, scanNumber}.params.ReagentName;
                        previousFlowRate = self.dataset{channel, scanNumber}.params.FlowRate;
                    end
                end
            end % Loop through scan file
            % initialize fitPeakTracking
            self.appParams.fitPeakTracking = self.appParams.rawPeakTracking;
            delete(waitbar_handle);
        end % function
        
         %% load PeakTracking.mat data
% obsoleted by shon 28 nov 2014
%         function self = loadPeakTrackingData (self)
%             % create waitbar
%             waitbar_handle = waitbar(0, 'Loading PeakTracking.mat data...');
%             % Load Peak Track Data
%             filename = strcat(self.path.datasetDir, 'PeakTracking.mat');
%             if exist(filename, 'file')
%                 loadedRawPeakTrackData = load(filename);
%             else
%                 msg = strcat(filename, ' does not exist.');
%                 error (msg);
%             end
%             self.appParams.rawPeakTracking = loadedRawPeakTrackData.peaksTrackData;
%             % assign unfitted peaks to the fitted peak array (since this is
%             % what gets plotted) and overwrite with the fitted peak data
%             self.appParams.fitPeakTracking = self.appParams.rawPeakTracking;
%             self.datasetParams.numOfChannels = length(self.appParams.rawPeakTracking);
%             self.datasetParams.numOfPeaks = zeros(self.datasetParams.numOfChannels, 1);
%             self.isPeak = cell(self.datasetParams.numOfChannels, 1);
%             for ch = self.datasetParams.includedChannel
%                 waitbar(ch/self.datasetParams.includedChannel(end), waitbar_handle, sprintf('Loading Peak Tracking Data: %d%%', round(100*ch/self.datasetParams.includedChannel(end))));
%                 % determine # of tracked peaks in each scanline channel
%                 [~, self.datasetParams.numOfPeaks(ch)] = size(self.appParams.rawPeakTracking{ch});
%                 self.isPeak{ch} = zeros(self.datasetParams.numOfPeaks(ch), 1);
%                 % this code fixes a bug in the big test setup where a peak
%                 % gets saved on peak selection and results in one extra
%                 % entry in the PeakTracking.mat file over the
%                 % Scan<x>.mat files
%                 for pp = 1:self.datasetParams.numOfPeaks(ch)
%                     if length(self.appParams.rawPeakTracking{ch}{pp}) > self.lastScanNumber
%                         self.appParams.rawPeakTracking{ch}{pp} = self.appParams.rawPeakTracking{ch}{pp}(2:end);
%                     end
%                     if isfield(loadedRawPeakTrackData, 'isPeak')
%                         self.isPeak{ch}(pp) = loadedRawPeakTrackData.isPeak(ch);
%                     end
%                 end
%                 % loop through all the scanlines and instantiate peak objects
%                 for scanNumber = 1:self.lastScanNumber
% %                     % Grab peak locations at this channel
% %                     allPeaksInfo = struct(...
% %                         'isPeak', self.isPeak{ch}, ...
% %                         'numOfPeaks', self.datasetParams.numOfPeaks(ch), ...
% %                         'peakLocation', []);
% %                     for pp = 1:self.datasetParams.numOfPeaks(ch)
%                         % instantiate peak objects here?
%                         peakLocation = zeros(1, self.datasetParams.numOfPeaks(ch));
%                         for pp = 1:self.datasetParams.numOfPeaks(ch)
%                             peakLocation(pp) = self.appParams.rawPeakTracking{ch}{pp}(scanNumber);
%                         end
%                         scanInfo = struct(...
%                             'isPeak', self.isPeak{ch}, ...
%                             'numOfPeaks', self.datasetParams.numOfPeaks(ch), ...
%                             'peakLocation', peakLocation);
%                         self.dataset{ch, scanNumber}.updateScanInfo(scanInfo);
%                         self.dataset{ch, scanNumber}.createPeakObject();
% %                         allPeaksInfo.peakLocation(end + 1) = self.appParams.rawPeakTrackingN{ch}{pp}(scanNumber);
% %                     end
%                 end
%             end % for ch
% %             % Determine channel and peaks information
% %             for ch = 1:self.datasetParams.numOfChannels
% %                 if ~isempty(self.appParams.rawPeakTrackingN{ch})
% %                     self.datasetParams.includedChannel(end + 1) = ch;
% %                     self.datasetParams.numOfPeaks(ch) = length(self.appParams.rawPeakTrackingN{ch});
% %                 end
% %             end
%             delete(waitbar_handle);
%         end % function

        %% create preProcessDataset
        function self = preProcessDataset(self)
            % local variables
%             fitWindowIndex{4}{10}(2) = []; % default, assume <4 ch and <10 pks, 2 bounds
%             wvlWindow{4}{10} = []; % default, assume <4 ch and <10 pks   
            strResponse = '';
            % Load data from Scan<x>.mat files and add *.peakResults
            % create waitbar
            waitbar_handle = waitbar(0, 'Preprocessing dataset');
            % debug
            if self.DEBUG
                firstScanNumber = self.firstScanNumber
                lastScanNumber = self.lastScanNumber
            end
            for scan = self.firstScanNumber:self.lastScanNumber
                filename = strcat(self.path.datasetDir, 'Scan', num2str(scan), '.mat');
                if ~exist(filename, 'file')
                    waitbar(scan/self.lastScanNumber, waitbar_handle, sprintf('Scan#%d: File Missing!', scan));
                else % Scan File Exist
                    waitbar(scan/self.lastScanNumber, waitbar_handle, sprintf('Loading: %d%%', round(100*scan/self.lastScanNumber)));
                    scanFileData = load(filename);
                    % **create peakResults struct like this below
                    % for reference only (copied from deviceClass.m)
                    %         peakResults = struct(...
                    %             'isPeak', self.isPeak, ...
                    %             'peakWvl', cell(size(self.PeakLocations)), ...
                    %             'wvlWindow', cell(size(self.PeakTrackWindows)));
                    %         for d = 1:self.NumOfDetectors
                    %             for p = 1:length(self.PeakLocations{d})
                    %                 peakResults.peakWvl{d}{p} = self.PeakLocations{d}{p}(self.scan);
                    %                 peakResults.wvlWindow{d}{p} = self.ThisSweep(d).wvl(self.PeakTrackWindows{d}{p});
                    %             end
                    %         end
                    % first scan special case-select peaks
                    
                    %% jonasf : added for testbench data analysis
                    if ~isfield(scanFileData.params, 'ReagentName')
                        disp('*** Appending the scan file ReagentName ***');
                        temp_params = scanFileData.params; 
                        scanFileData = rmfield(scanFileData, 'params');
                        params = temp_params ; 
                        params.ReagentName = 'Air';
                        save(filename, 'params', '-append');
                    end
                    scanFileData = load(filename);                   
                    if ~isfield(scanFileData.params, 'FlowRate')
                        disp('*** Appending the scan file FlowRate ***');
                        temp_params = scanFileData.params;
                        scanFileData = rmfield(scanFileData, 'params');
                        params = temp_params ;
                        params.FlowRate = '0';
                        save(filename, 'params', '-append');
                    end
      
                    if scan == self.firstScanNumber
                        % Erase previous preProcess Data
                        if isfield(scanFileData, 'peakResults')
                            scanFileData = rmfield(scanFileData, 'peakResults');
                        end
                        % Determine channel and peaks information
                        [~, self.datasetParams.numOfChannels] = size(scanFileData.scanResults);
                        self.datasetParams.includedChannel = []; 
                        for ii = 1:self.datasetParams.numOfChannels
                            if ~scanFileData.scanResults(1,ii).Data(1,1) == 0 % check in first wvl value is 0
                                self.datasetParams.includedChannel(end + 1) = ii;
                            end
                        end
                        % prompt user to select peaks
                        peakResults = selectPeaks(scanFileData); % returns structure described above**
                        % loop through active channels
                        for channel = self.datasetParams.includedChannel % number of channels
                            tempWvl = scanFileData.scanResults(channel).Data(:,1);
                            tempPwr = scanFileData.scanResults(channel).Data(:,2);                    
                            % find number of peaks selected for this channel
                            numberOfPeaks(channel) = length(peakResults.peakWvl{channel});
                            % loop through peaks
                            for peak = 1:numberOfPeaks(channel)
                                % size of window (save for other scan entries.. it doesn't change)
                                wvlWindow{channel}{peak} = peakResults.wvlWindow{channel}{peak}; % size in nm
                                % index of peak wavelength to find window middle
                                peakWvlIndex = find(...
                                    peakResults.peakWvl{channel}{peak}==...
                                    tempWvl); % entire scan wavelength array
                                index = peakWvlIndex; % for debug statement below
                                % resolution to find number of samples in window
                                resolution = (tempWvl(2)-tempWvl(1));
                                % number of samples in window
                                samplesInWindow{channel}{peak} = wvlWindow{channel}{peak}/resolution; % window size (nm) / step (nm)
                                % lower bound for fit window into full wvl array
                                if (peakWvlIndex - samplesInWindow{channel}{peak}/2)>1
                                    fitWindowIndex{channel}{peak}(self.LB) =...
                                        peakWvlIndex - round(samplesInWindow{channel}{peak}/2);
                                else
                                    fitWindowIndex{channel}{peak}(self.LB)=1;
                                end
                                % upper bound for fit window into full wvl array
                                if (peakWvlIndex + samplesInWindow{channel}{peak}/2)< length(tempWvl)
                                    fitWindowIndex{channel}{peak}(self.UB) =...
                                        peakWvlIndex + round(samplesInWindow{channel}{peak}/2);
                                else
                                    fitWindowIndex{channel}{peak}(self.UB)=length(tempWvl);
                                end
                                % debug
                                if self.DEBUG
                                    disp('------------------------------');
                                    disp('appClass preProcessDataset => first scan');
                                    msg = strcat('::Scan=',num2str(scan),...
                                        '::Channel=',num2str(channel),...
                                        '::Peak=',num2str(peak),'/',num2str(numberOfPeaks(channel)));
                                    disp(msg);
                                    lowerbound = fitWindowIndex{channel}{peak}(self.LB);
                                    upperbound = fitWindowIndex{channel}{peak}(self.UB);
                                    msg = strcat('::LB=',num2str(lowerbound),...
                                        '::C=',num2str(index),....
                                        '::UB=',num2str(upperbound));
                                    disp(msg);
                                    peakWvl = peakResults.peakWvl{channel}{peak};
                                    msg = strcat('::peakWvl=',num2str(peakWvl),...
                                        '::WindowSize=', num2str(resolution*(upperbound-lowerbound)),...
                                        '::samplesInWindow=',num2str(samplesInWindow{channel}{peak}));
                                    disp(msg);
                                    if ~strcmp(strResponse,'c') % continue to end
                                        strResponse = input('Continue? [<CR> -or- c to continuous] = ','s'); % returns as string
                                    end
                                end
                            end % peak loop (first case)
                        end % channel loop (first case)
                    else % scan > self.firstScanNumber; don't do it again for the first scan
                        % Erase previous preProcess Data
                        if isfield(scanFileData, 'peakResults')
                            scanFileData = rmfield(scanFileData, 'peakResults');
                        end
                        
                        % process data
                        for channel = self.datasetParams.includedChannel % number of channels
                            tempWvl = scanFileData.scanResults(channel).Data(:,1);
                            tempPwr = scanFileData.scanResults(channel).Data(:,2);
                            % look for min/max and re-adjust window
                            
                            %this will still work if numberOfPeaks = 0 
                            for peak = 1:numberOfPeaks(channel)
                                % assign wvl windows
%Reverse of line 1064
%                                peakResults.wvlWindow{channel}{peak} = wvlWindow{channel}{peak};
                                
                                % assign peakWvl
                                if peakResults.isPeak(channel) % maxima
                                    [peakResults.peakPwr{channel}{peak}, index] =...
                                        max(tempPwr(...
                                        fitWindowIndex{channel}{peak}(self.LB):...
                                        fitWindowIndex{channel}{peak}(self.UB)));
                                else % minima
                                    [peakResults.peakPwr{channel}{peak}, index] =...
                                        min(tempPwr(...
                                        fitWindowIndex{channel}{peak}(self.LB):...
                                        fitWindowIndex{channel}{peak}(self.UB)));
                                end % if isPeak
                                % peakWvl
                                if self.DEBUG
                                   msg = strcat('index=', num2str(index));
                                   disp(msg);
                                end
                                %index is from the peak window
                                abs_peak_index = fitWindowIndex{channel}{peak}(self.LB)+index(end);
                                peakResults.peakWvl{channel}{peak} = tempWvl(abs_peak_index);
                                % debug

                                % re-center window for next fit
                                if ceil(abs_peak_index-samplesInWindow{channel}{peak}/2) < 1
                                    fitWindowIndex{channel}{peak}(self.LB) = 1;
                                else
                                    fitWindowIndex{channel}{peak}(self.LB) = ...
                                        ceil(abs_peak_index - ...
                                        samplesInWindow{channel}{peak}/2);
%                                         ceil(fitWindowIndex{channel}{peak}(self.LB)+index - ...
%                                        samplesInWindow{channel}{peak}/2);
                                end
                                if floor(abs_peak_index + samplesInWindow{channel}{peak}/2) > length(tempWvl)
                                    fitWindowIndex{channel}{peak}(self.LB) = length(tempWvl);
                                else
                                    fitWindowIndex{channel}{peak}(self.UB) = ...
                                        floor(abs_peak_index + ...
                                        samplesInWindow{channel}{peak}/2);
  %                                         floor(fitWindowIndex{channel}{peak}(self.LB)+index + ...
 %                                         samplesInWindow{channel}{peak}/2);
                                end
                                if self.DEBUG
                                    disp('------------------------------');
                                    disp('appClass preProcessDataset =>');
                                    msg = strcat('::Scan=',num2str(scan),'::Channel=',num2str(channel),...
                                        '::Peak=',num2str(peak),'/',num2str(numberOfPeaks(channel)));
                                    disp(msg);
                                    lowerbound = fitWindowIndex{channel}{peak}(self.LB);
                                    upperbound = fitWindowIndex{channel}{peak}(self.UB);
                                    msg = strcat('::LB=',num2str(lowerbound),'::C=',num2str(index+lowerbound),...
                                        '::UB=',num2str(upperbound));
                                    disp(msg);
                                    peakWvl = peakResults.peakWvl{channel}{peak};
                                    msg = strcat('::peakWvl=',num2str(peakWvl),...
                                        '::WindowSize=', num2str(resolution*(upperbound-lowerbound)),...
                                        '::samplesInWindow=', num2str(samplesInWindow{channel}{peak}));
                                    disp(msg);
                                    if ~strcmp(strResponse,'c') % continue to end
                                        strResponse = input('Continue? [y or c to continue] = ','s');
                                    end
                                end
                       
                                
                                
                                
                                
                            end % peak loop
                        end % channel loop
                        
                    end % first scan
                    % add peakResults to scanFileData
                    % re-write file
                    msg = strcat('Saving peakResults to', filename);
                    disp(msg);
                    save(filename, 'peakResults', '-append');
                    
                end % if file exists
            end % scan loop
            delete(waitbar_handle);
        end % preProcessDataset
        
        %% createsetAnalysisFile
        function self = setAnalysisFile(self, varargin)
            if isempty (varargin)
                % create <dateTag> for this analysis file
                dateTag = datestr(now, 'yyyy.mm.dd@HH.MM'); % time stamp
                self.path.analysisFile = strcat(self.path.datasetDir, '_Analysis_', dateTag, '.mat');
            else
                self.path.analysisFile = strcat(self.path.datasetDir, varargin{1});
            end
        end
        
%         %% load previous analysis data
%         function self = loadPreviousAnalysis(self)
%             % Load Old Analysis Data, if any
% %             oldsetAnalysisFile = strcat(self.path.datasetDir, '*_Analysis_*.mat');
% %             fileList = dir(oldsetAnalysisFile);
%             for fl = 1:length(fileList)
%                 fileName = fileList(fl).name;
%                 tempInd = strfind(lower(fileName), 'channel');
%                 ch = str2double(fileName(tempInd + 7));
%                 oldsetAnalysisFileAll = load([self.path.datasetDir, fileName]);
%                 startScan = oldsetAnalysisFileAll.startScan;
%                 stopScan = oldsetAnalysisFileAll.stopScan;
%                 oldAnalysisPeakTrackData = oldsetAnalysisFileAll.PeakTracking;
%                 [addNumOfPeaks, ~] = size(oldAnalysisPeakTrackData);
%                 for an = 1:addNumOfPeaks
%                     tempData = [ones(1, startScan - self.firstScanNumber)*oldAnalysisPeakTrackData(an, 1), oldAnalysisPeakTrackData(an, :), ones(1, self.lastScanNumber - stopScan)*oldAnalysisPeakTrackData(an, end)];
%                     self.appParams.rawPeakTrackingN{ch}(end + 1) = {tempData};
%                     self.appParams.rawPeakTrackingN{ch}(end + 1) = {tempData - tempData(1)};
%                 end
%             end
%         end % function
        
        %% save analsyis
        function self = saveAnalysis(self)
            % parameters from app class
%             app.excludedScans = self.appParams.tempActiveChannelExcludedScans;
%             app.peakTracking = self.appParams.rawPeakTracking;
%             app.fitPeakTracking = self.appParams.fitPeakTracking;
            app.appParams = self.appParams;
            
            % parameters from scan class
            for channel = self.datasetParams.includedChannel
                % loop through all the scanlines and instantiate peak objects
                for scanNumber = 1:self.lastScanNumber
                    scan.excludeScan{channel, scanNumber} =...
                        self.dataset{channel, scanNumber}.excludeScan;
                end
            end

            % parameters from peak peak class
            for channel = self.datasetParams.includedChannel
                % loop through all the scanlines and instantiate peak objects
                for scanNumber = 1:self.lastScanNumber
                    for peak = 1:self.datasetParams.numOfPeaks(channel)
                        peakData{channel, scanNumber}.peaks{peak} = ...
                            self.dataset{channel, scanNumber}.peaks{peak}.savePeakData();
                    end
                end
            end
            
            save(self.path.analysisFile, 'app', 'scan', 'peakData');
        end
        
        function self = loadAnalysis(self, varargin)
            fn = strcat(self.path.datasetDir, varargin{1});
            S = load(fn); % loads everything into previousAnalysis struct
            % parameters from app class
%             self.appParams.tempActiveChannelExcludedScans = S.app.excludedScans;
%             self.appParams.rawPeakTracking = S.app.peakTracking;
%             self.appParams.fitPeakTracking = S.app.fitPeakTracking;
            self.appParams = S.app.appParams;
         
            % parameters from scan class
            for channel = self.datasetParams.includedChannel
                % loop through all the scanlines and instantiate peak objects
                for scanNumber = 1:self.lastScanNumber
                    self.dataset{channel, scanNumber}.excludeScan = ...
                        S.scan.excludeScan{channel, scanNumber};
                end
            end

            % parameters from peak peak class
            for channel = self.datasetParams.includedChannel
                % loop through all the scanlines and instantiate peak objects
                for scanNumber = 1:self.lastScanNumber
                    for peak = 1:self.datasetParams.numOfPeaks(channel)
                        peakData = S.peakData{channel, scanNumber}.peaks{peak};
                        self.dataset{channel, scanNumber}.peaks{peak}.loadPeakData(peakData);
                        
                        % Vince add this to cope with non-existing
                        % properties in old analysis file
                        self.dataset{channel, scanNumber}.peaks{peak}.raw.corrRho = 0;
                        self.dataset{channel, scanNumber}.peaks{peak}.raw.corrPval = 0;
                        % Delete soon ----------------------------------
                    end
                end
            end
            clear('S'); % remove struct
            self.updateGUI();
        end
        
        %% update plots
        function updatePlotting(self)
            waitBarH = waitbar(0.1, 'Updating plots. Please wait patiently.');
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %% Update plotting in scan panel
            % plot this scan bigger scan window
            plot(self.gui.panelScanThisScanFig, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.wvl, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.pwr);  
                hold(self.gui.panelScanThisScanFig, 'on')
            % show previous scan along w/ this scan in bigger scan window
            if self.contextMenu.scanPlot.showPrevious && self.appParams.activeScan > self.firstScanNumber
                plot(self.gui.panelScanThisScanFig, ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.wvl, ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.pwr, 'g');
                legend(self.gui.panelScanThisScanFig, 'This', 'Previous', 'Location', 'SouthEast');
            end
          
            % plot crosshairs on selected peaks in scan window
            for nm = 1:self.datasetParams.numOfPeaks(self.appParams.activeChannel)
                thisPeakLocationX = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{nm}.raw.peakWvl;
                thisPeakLocationY = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{nm}.raw.peakPwr;
                plot(self.gui.panelScanThisScanFig, thisPeakLocationX, thisPeakLocationY, 'r+');
                text(thisPeakLocationX, thisPeakLocationY, sprintf('#%d', nm), 'Parent', self.gui.panelScanThisScanFig);
                if self.appParams.activeScan > self.firstScanNumber
                    previousthisPeakLocationX = self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.peaks{nm}.raw.peakWvl;
                    previousthisPeakLocationY = self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.peaks{nm}.raw.peakPwr;
                    plot(self.gui.panelScanPreviousScanFig, previousthisPeakLocationX, previousthisPeakLocationY, 'r+');
                    text(previousthisPeakLocationX, previousthisPeakLocationY, sprintf('#%d', nm), 'Parent', self.gui.panelScanPreviousScanFig);
                end
            end
            hold(self.gui.panelScanThisScanFig, 'off'); % main scan window
            
            % plot previous peak in smaller scan window
            if self.appParams.activeScan > self.firstScanNumber
                plot(self.gui.panelScanPreviousScanFig, ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.wvl, ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.pwr, 'g');
                hold(self.gui.panelScanPreviousScanFig, 'on')
            end
            hold(self.gui.panelScanPreviousScanFig, 'off'); % smaller window
            set(self.gui.panelScanExcludeCheckbox, 'Value', self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.excludeScan)
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %% Update plotting in peak panel            
            % Plot Peaks
            plot(self.gui.panelPeakThisPeakFig, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.wvls, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.pwrs)
            hold(self.gui.panelPeakThisPeakFig, 'on')
            plot(self.gui.panelPeakThisPeakFig, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.peakWvl, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.peakPwr, 'b+');
            plot(self.gui.panelPeakThisPeakFig, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.fitPeakWvl, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.fitPeakPwr, 'r+');
            plot(self.gui.panelPeakThisPeakFig, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.fitWvls, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.fitPwrs, 'r');
            legend(self.gui.panelPeakThisPeakFig, {'Raw', 'RawPeak', 'FitPeak', 'Fit'}, 'Location', 'SouthEast');
            % plot Q
            if self.contextMenu.peakPlot.addQ
                % calculate Q
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.calculateQ();
                % get Q
                [minus3dBWvl, plus3dBWvl, Q, baseline] = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.reportQ();
                % calculate y-values for line
                yLimit = get(self.gui.panelPeakThisPeakFig, 'ylim');
                % plot line at -3dB
                plot(self.gui.panelPeakThisPeakFig, ...
                    minus3dBWvl*ones(10, 1),...
                    linspace(yLimit(1), yLimit(2), 10), 'r:');                
                % plot line at +3dB
                plot(self.gui.panelPeakThisPeakFig, ...
                    plus3dBWvl*ones(10, 1),...
                    linspace(yLimit(1), yLimit(2), 10), 'r:');
                % Plot baseline for Q estimation - only useful for null
                xLimit = get(self.gui.panelPeakThisPeakFig, 'xlim');
                plot(self.gui.panelPeakThisPeakFig, ...
                    linspace(xLimit(1), xLimit(2), 10), ...
                    baseline*ones(10, 1), 'g--');
                

                textStr = strcat('Q=',num2str(round(Q)));               
                %textStr = textwrap(textStr, 25);
                self.annotationQText = text(...
                     self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.peakWvl, ...
                     self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.peakPwr, ...
                     textStr, 'Fontsize', 10, 'Parent', self.gui.panelPeakThisPeakFig);
            end
            hold(self.gui.panelPeakThisPeakFig, 'off')
            % Previous & Next Peak
            plot(self.gui.panelPeakPreviousThisNextPeakFig, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.wvls, ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.pwrs)
            hold(self.gui.panelPeakPreviousThisNextPeakFig, 'on')
            if self.appParams.activeScan > self.firstScanNumber
                plot(self.gui.panelPeakPreviousThisNextPeakFig, ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.peaks{self.appParams.activePeak}.raw.wvls, ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.peaks{self.appParams.activePeak}.raw.pwrs, 'g')
            end
            if self.appParams.activeScan < self.lastScanNumber
                plot(self.gui.panelPeakPreviousThisNextPeakFig, ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan + 1}.peaks{self.appParams.activePeak}.raw.wvls, ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan + 1}.peaks{self.appParams.activePeak}.raw.pwrs, 'r')
            end
            if self.appParams.activeScan > self.firstScanNumber &&...
                    self.appParams.activeScan < self.lastScanNumber
                legend(self.gui.panelPeakPreviousThisNextPeakFig, 'This', 'Previous', 'Next', 'Location', 'SouthEast');
            end
            hold(self.gui.panelPeakPreviousThisNextPeakFig, 'off')
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %% Update plotting in peak tracking window
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            waitbar(0.4, waitBarH);
            % update peak tracking
            self.createPeakTracking();
            waitbar(0.7, waitBarH);
            % update peak tracking window plot
            self.plotPeakTracking();
            waitbar(1, waitBarH, 'Finished.');
            delete(waitBarH);
            
            %line below would allow for multiple peak tracking
            %set(self.gui.panelPeakIsPeakCheckbox, 'Value', self.isPeak{self.appParams.activeChannel}(self.appParams.activePeak));
            set(self.gui.panelPeakIsPeakCheckbox, 'Value', self.isPeak(self.appParams.activeChannel));
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% update plotting in peak tracking window
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function self = plotPeakTracking(self)
            
            tempRawPeakTrackingArray = self.appParams.rawPeakTracking{self.appParams.activeChannel}{self.appParams.activePeak};
            %tempRawPeakTrackingArray = self.appParams.rawPeakTracking;
            % assume that fitPeakTracking gets set to rawPeakTracking initially
            tempFitPeakTrackingArray = self.appParams.fitPeakTracking{self.appParams.activeChannel}{self.appParams.activePeak};
            tempScanTemperature = self.scanTemperatures;
            tempPeakTrackingPlotCropValues = self.peakTrackingPlotCropValues;
            %tempFitPeakTrackingArray = self.appParams.fitPeakTracking;
            tempXData = self.appParams.xData;
            
            if self.contextMenu.trackedPeaksPlot.inPicoMeters
                yLabelName = 'Wavlength [pm]';
                yScale = 1000;
            else
                yLabelName = 'Wavlength [nm]';
                yScale = 1;
            end
            
            if self.DEBUG
                disp('plotPeakTracking DEBUG');
                plotShowRawTracking = self.contextMenu.trackedPeaksPlot.plotRaw
                size(tempRawPeakTrackingArray)
                size(tempFitPeakTrackingArray)
                activeChannel = self.appParams.activeChannel
                activePeak = self.appParams.activePeak
            end

            
            if self.DEBUG
               numberOfScans = self.lastScanNumber-self.firstScanNumber
               % inArray = length(tempRawPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak})
                inArray = length(tempRawPeakTrackingArray);
            end
            
            % normalized data
            if self.contextMenu.trackedPeaksPlot.normalize || self.contextMenu.trackedPeaksPlot.subtractReference
                % normalizationValue = tempRawPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(self.firstScanNumber);
                normalizationValue = tempRawPeakTrackingArray(self.firstScanNumber);
%                 for scan = self.firstScanNumber:self.lastScanNumber
%                     tempRawPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(scan) = ...
%                         tempRawPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(scan) -...
%                         normalizationValue;
%                     tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(scan) = ...
%                         tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(scan) -...
%                         normalizationValue;
%                 end
                tempRawPeakTrackingArray = tempRawPeakTrackingArray - normalizationValue;
                tempFitPeakTrackingArray = tempFitPeakTrackingArray - normalizationValue;
                if self.contextMenu.trackedPeaksPlot.inPicoMeters
                    yLabelName = 'Wavlength shift [pm]';
                else
                    yLabelName = 'Wavlength shift [nm]';
                end
            end
            
            % subtract reference (normalize both)
            if ~strcmpi(self.appParams.referenceToSubract, '') && self.contextMenu.trackedPeaksPlot.subtractReference
                % strsplit is not in MATLAB R2011
%                [strVals,~] = strsplit(self.appParams.referenceToSubract,'.');
                strVals = splitstring(self.appParams.referenceToSubract,'.');
                refCh = str2double(strVals(1));
                refPk = str2double(strVals(2));
                % subtract 'normalized' peak array from fit peak array
                referenceFitPeakTrackingArray = self.appParams.fitPeakTracking{refCh}{refPk};
                normalizationValue = referenceFitPeakTrackingArray(self.firstScanNumber);
                tempFitPeakTrackingArray = tempFitPeakTrackingArray - (referenceFitPeakTrackingArray - normalizationValue);
%                 normalizationValue = self.dataset{refCh,self.firstScanNumber}.peaks{refPk}.fitPeakWvl;
%                 for scan = self.firstScanNumber:self.lastScanNumber
%                     tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(scan) = ...
%                         tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(scan) -...
%                         (self.dataset{refCh,scan}.peaks{refPk}.fitPeakWvl-normalizationValue);
%                 end
            end
            

            
            if self.testParams.AssayParams.TranslateRecipeTimeToSweeps
                xLabelName = 'Scan Number';
            else
                xLabelName = 'Time [min]';
            end
            
            % scale y data (nm vs. pm)
%             tempRawPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak} = ...
%                 tempRawPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}*yScale;
%             tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak} = ...
%                 tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}*yScale;
            tempRawPeakTrackingArray = tempRawPeakTrackingArray*yScale;
            tempFitPeakTrackingArray = tempFitPeakTrackingArray*yScale;
            
            % Update plot data with excluded scans
            if ~self.contextMenu.trackedPeaksPlot.plotExcludedScans
                includedScans = ones(size(tempRawPeakTrackingArray));
                includedScans(self.appParams.tempActiveChannelExcludedScans) = 0;
                includedScans = find(includedScans~=0);
                tempRawPeakTrackingArray = tempRawPeakTrackingArray(includedScans);
                tempFitPeakTrackingArray = tempFitPeakTrackingArray(includedScans);
                tempScanTemperature = tempScanTemperature(includedScans);
                tempXData = tempXData(1:length(includedScans));
                leftExclude = sum(self.appParams.tempActiveChannelExcludedScans < tempPeakTrackingPlotCropValues(self.LB));
                rightExclude = sum(self.appParams.tempActiveChannelExcludedScans <= tempPeakTrackingPlotCropValues(self.UB));
                tempPeakTrackingPlotCropValues(self.LB) = tempPeakTrackingPlotCropValues(self.LB) - leftExclude;
                tempPeakTrackingPlotCropValues(self.UB) = tempPeakTrackingPlotCropValues(self.UB) - rightExclude;
            end
            
            % shons 26 nov 2014
            % always plot fitPeakTracking regardless. user can choose to
            % overlay rawPeakTracking but the assumption is that only fit
            % data (even if it's max from raw data) will be used in pub 
            if self.contextMenu.trackedPeaksPlot.plotTemp
                if self.contextMenu.trackedPeaksPlot.plotRaw
%                     [ax, h1, h2] = plotyy(self.gui.peakTrackingFig(1),...
%                         tempXData,...
%                         [tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak};
%                         tempRawPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}], ...
%                         tempXData, self.scanTemperatures);
                    [self.gui.peakTrackingAndTempFig, h1, h2] = plotyy(self.gui.peakTrackingFig(1),...
                        tempXData(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)),...
                        [tempFitPeakTrackingArray(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB));...
                        tempRawPeakTrackingArray(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB))], ...
                        tempXData(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)),...
                        tempScanTemperature(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)));
                else
%                     [ax, h1, h2] = plotyy(self.gui.peakTrackingFig(1), ...
%                         tempXData, tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}, ...
%                         tempXData, self.scanTemperatures);
                    [self.gui.peakTrackingAndTempFig, h1, h2] = plotyy(self.gui.peakTrackingFig(1), ...
                        tempXData(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)),...
                        tempFitPeakTrackingArray(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)),...
                        tempXData(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)),...
                        tempScanTemperature(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)));
                end
                
                set(get(self.gui.peakTrackingAndTempFig(1),'Ylabel'), 'String', yLabelName, 'Color', 'b');
                set(h2, 'Color', 'k', 'LineWidth', 1, 'LineStyle',':');
                set(get(self.gui.peakTrackingAndTempFig(2),'Ylabel'), 'String', 'Temp (C)', 'Color', 'k');
            else
                if self.contextMenu.trackedPeaksPlot.plotRaw
%                     plot(self.gui.peakTrackingFig(1), tempXData,...
%                         [tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak};...
%                         tempRawPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}]);
                    plot(self.gui.peakTrackingFig(1),...
                        tempXData(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)),...
                        [tempFitPeakTrackingArray(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB));...
                        tempRawPeakTrackingArray(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB))]);
                    legend(self.gui.peakTrackingFig(1), 'Fit', 'min/max');
                else
%                     plot(self.gui.peakTrackingFig(1), tempXData, tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak});
                    plot(self.gui.peakTrackingFig(1),...
                        tempXData(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)),...
                        tempFitPeakTrackingArray(tempPeakTrackingPlotCropValues(self.LB):tempPeakTrackingPlotCropValues(self.UB)));
                end
                ylabel(self.gui.peakTrackingFig(1), yLabelName);
                self.gui.peakTrackingAndTempFig = self.gui.peakTrackingFig;
            end
            
            %% add y-difference measurements (if enabled)
            if ~isempty(self.contextMenu.trackedPeaksPlot.yDifferenceValues)
                hold(self.gui.peakTrackingFig(1), 'on');
                yDifferenceValues = zeros(size(self.contextMenu.trackedPeaksPlot.yDifferenceValues.y));
                for ii = 1:length(yDifferenceValues)
                    [~, xIndex] = min(abs(self.appParams.xData - self.contextMenu.trackedPeaksPlot.yDifferenceValues.x(ii)));
                    yDifferenceValues(ii) = tempFitPeakTrackingArray(xIndex);
                    % plot line
                    plot(self.gui.peakTrackingFig(1),...
                        xlim, ...
                        yDifferenceValues(ii)*ones(size(xlim)),...
                        '-.og')
                end
                if length(yDifferenceValues) >= 2
                    % plot the difference as well
                    difference = yDifferenceValues(2) - yDifferenceValues(1);
                    % midX = mean(self.contextMenu.trackedPeaksPlot.yDifferenceValues.x);
                    midY = mean(yDifferenceValues);
                    xLeft = xlim;
                    xLeft = xLeft(1);
                    text(xLeft, midY, num2str(difference),  'Parent', self.gui.peakTrackingFig(1));
                end
                hold(self.gui.peakTrackingFig(1), 'off');
            end
            
            %% add reagents
            if self.contextMenu.trackedPeaksPlot.showReagents
                self.showReagents()
            end
            hold(self.gui.peakTrackingFig(1), 'on');
            
            %note jonasf: there was  wired merge conflict;
            if ~self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.excludeScan
                scanNumberCorrection = sum(self.appParams.activeScan >= self.appParams.tempActiveChannelExcludedScans);
                correctedScanNum = self.appParams.activeScan - scanNumberCorrection;
%                 plot(self.gui.peakTrackingFig(1), ...
%                     tempXData(self.appParams.activeScan),...
%                     tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(self.appParams.activeScan),...
%                     'ro');
                if self.contextMenu.trackedPeaksPlot.showCurrentPosition
                    plot(self.gui.peakTrackingFig(1), ...
                    tempXData(correctedScanNum),...
                    tempFitPeakTrackingArray(correctedScanNum),...
                    'ro');
                    yLimit = get(self.gui.peakTrackingFig(1), 'ylim');
                    plot(self.gui.peakTrackingFig(1), tempXData(correctedScanNum)*ones(10, 1),...
                        linspace(yLimit(1), yLimit(2), 10), 'r:');
%                     plot(self.gui.peakTrackingFig, ...
%                         tempXData(self.appParams.activeScan),...
%                         tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(self.appParams.activeScan),...
%                         'ro');
                    plot(self.gui.peakTrackingFig(1), ...
                        tempXData(correctedScanNum),...
                        tempFitPeakTrackingArray(correctedScanNum),...
                        'ro');
                end
            %
            end
%                 plot(self.gui.peakTrackingFig(1),...
%                     self.appParams.xData(self.appParams.activeScan),...
%                     tempFitPeakTrackingArray{self.appParams.activeChannel}{self.appParams.activePeak}(self.appParams.activeScan),...
%                     'kx');
%                   plot(self.gui.peakTrackingFig(1),...
%                     tempXData(self.appParams.activeScan),...
%                     tempFitPeakTrackingArray(self.appParams.activeScan),...
%                     'kx');
%             end
            
            % Annotation Text
            [numOfText, ~] = size(self.annotationText);
            for tt = 1:numOfText
                textStr = self.annotationText{tt, 1};
                textPos =  self.annotationText{tt, 2};
                text(textPos(1), textPos(2), textStr,  'Parent', self.gui.peakTrackingFig(1))
            end
            
            hold(self.gui.peakTrackingFig(1), 'off');
            xlabel(xLabelName)
        end
                
        function showReagents(self)
            tempReagentChangeIndex = self.reagentChangeIndex;
            startScan = tempReagentChangeIndex(1);
            while any(self.appParams.tempActiveChannelExcludedScans == startScan)
                tempReagentChangeIndex(1) = tempReagentChangeIndex(1) + 1;
                startScan = tempReagentChangeIndex(1);
            end
            for rc = 2:length(tempReagentChangeIndex)
                condition = self.appParams.tempActiveChannelExcludedScans <= tempReagentChangeIndex(rc);
                if ~isempty(condition)
                    tempReagentChangeIndex(rc) = tempReagentChangeIndex(rc) - length(condition);
                end
            end
            
            hold(self.gui.peakTrackingFig(1), 'on');
            yLimit = get(self.gui.peakTrackingFig(1), 'ylim');
            for rc = 2:length(tempReagentChangeIndex)
                previousRcIndex = min(tempReagentChangeIndex(rc - 1) + self.contextMenu.trackedPeaksPlot.reagentOffset, length(self.appParams.xData));
                rcIndex = min(tempReagentChangeIndex(rc) + self.contextMenu.trackedPeaksPlot.reagentOffset, length(self.appParams.xData));
                % 10 Jan 2015 ShonS -- adding the cropping feature
                % reagentChangeIndex = array w/ the scan #'s of reagent changes
                % only plot reagent changes within cropping bounds
                if self.peakTrackingPlotCropValues(self.LB) <= tempReagentChangeIndex(rc) &&...
                        tempReagentChangeIndex(rc) <= self.peakTrackingPlotCropValues(self.UB)
                    plot(self.gui.peakTrackingFig(1), self.appParams.xData(rcIndex)*ones(10, 1), linspace(yLimit(1), yLimit(2), 10), 'k--');
                    text((self.appParams.xData(previousRcIndex) + self.appParams.xData(rcIndex))/2, yLimit(1) + (yLimit(2) - yLimit(1)) * 0.9, ...
                        sprintf(strrep(self.dataset{self.appParams.activeChannel, self.reagentChangeIndex(rc) - 1}.params.ReagentName, ' ', '\n')), ...
                        'Parent', self.gui.peakTrackingFig(1), ...
                        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0 0]);
                end
            end
            %Add last label
            text((self.appParams.xData(rcIndex) + self.appParams.xData(end))/2, yLimit(1) + (yLimit(2) - yLimit(1)) * 0.9, ...
                sprintf(strrep(self.dataset{self.appParams.activeChannel, self.reagentChangeIndex(rc)}.params.ReagentName, ' ', '\n')), ...
                'Parent', self.gui.peakTrackingFig(1), ...
                'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0 0]);
            hold(self.gui.peakTrackingFig(1), 'off');
        end
        
        function createTimeAndscanTemperatures(self)
            yearIndex = 1:4;
            monthIndex = 6:7;
            dayIndex = 9:10;
            hourIndex = 12:13;
            minIndex = 15:16;
            secondIndex = 18:19;
            self.scanTimes = [];
            self.scanTemperatures = [];
            for scanNumber = self.firstScanNumber:self.lastScanNumber
                thisScanTime = ...
                    str2double(self.dataset{self.appParams.activeChannel, scanNumber}.timeStamp(dayIndex))*24*60 + ...
                    str2double(self.dataset{self.appParams.activeChannel, scanNumber}.timeStamp(hourIndex))*60 + ...
                    str2double(self.dataset{self.appParams.activeChannel, scanNumber}.timeStamp(minIndex)) + ...
                    str2double(self.dataset{self.appParams.activeChannel, scanNumber}.timeStamp(secondIndex))/60;
                self.scanTimes(end + 1) = thisScanTime; % in mins
                self.dataset{self.appParams.activeChannel, scanNumber}.relativeTime = thisScanTime - self.scanTimes(1);
                self.scanTemperatures(end + 1) = str2double(self.dataset{self.appParams.activeChannel, scanNumber}.params.StageTemp);
            end
            self.scanTimes = self.scanTimes - self.scanTimes(1);
        end
        
        function createPeakTracking(self)
            for ch = self.datasetParams.includedChannel
                for pp = 1:self.datasetParams.numOfPeaks(ch)
                    tempRawPeakTracking = [];
                    tempFitPeakTracking = [];
                    for scanNumber = self.firstScanNumber: self.lastScanNumber
                        % if ~self.dataset{ch, scanNumber}.excludeScan
                        tempRawPeakTracking(end + 1) = self.dataset{ch, scanNumber}.peaks{pp}.raw.peakWvl;
                        tempFitPeakTracking(end + 1) = self.dataset{ch, scanNumber}.peaks{pp}.fitPeakWvl();
                        % end
                    end
                    self.appParams.rawPeakTracking{ch}{pp} = tempRawPeakTracking;
%                    self.appParams.rawPeakTrackingN{ch}{pp} = tempPeakTracking - tempPeakTracking(1);
                    self.appParams.fitPeakTracking{ch}{pp} = tempFitPeakTracking;
                    %                    self.appParams.fitPeakTrackingN{ch}{pp} = tempFitPeakTracking - tempFitPeakTracking(1);
                end
            end
        end
        
        function updateTable(self)
            % ******Fill the Scan Info Table
            scanInfo = cell(size(get(self.gui.panelScanTable, 'Data')));
            % #1 DC Offset
            scanInfo{1, 2} = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.DCOffset;
            % #2 Correlation
            scanInfo{2, 2} = num2str(self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.corrRho);
            % #3 Reagent
            scanInfo{3, 2} = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.params.ReagentName;
            % #4 Temp
            scanInfo{4, 2} = self.scanTemperatures(self.appParams.activeScan);
            % #5 Time
            scanInfo{5, 2} = self.scanTimes(self.appParams.activeScan);
            % Previous Scan Info
            scanInfo(:, 1) = {'N/A'};
            if self.appParams.activeScan >= 2
                % #1 DC Offset
                scanInfo{1, 1} = self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.DCOffset;
                % #2 Correlation
                scanInfo{2, 1} = num2str(self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.corrRho);
                % #3 Reagent
                scanInfo{3, 1} = self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.params.ReagentName;
                % #4 Temp
                scanInfo{4, 1} = self.scanTemperatures(self.appParams.activeScan - 1);
                % #5 Time
                scanInfo{5, 1} = self.scanTimes(self.appParams.activeScan - 1);
            end
            set(self.gui.panelScanTable, 'Data', scanInfo);
            
            % ******Fill the Peak Info Table
            peakInfo = cell(size(get(self.gui.panelPeakTable, 'Data')));
            % #1 Window
            peakInfo{1, 2} = sprintf('[%.1f, %.1f]', ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.wvls(1), ...
                self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.wvls(end));
            % #2 Correlation
            peakInfo{2, 2} = round(self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.corrRho*1000)/1000;
            % #3 Peak Location
            peakInfo{3, 2} = round(self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.peakWvl*10)/10;
            % #4 Difference
            if self.appParams.activeScan >= 2
                previousLoc = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.peakWvl;
            else
                previousLoc = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.peakWvl;
            end
            peakInfo{4, 2} = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.peakWvl - previousLoc;
            % #5 Q
            peakInfo{5, 2} = 'N/A';
            
            % Previous Peak Info
            peakInfo(:, 1) = {'N/A'};
            if self.appParams.activeScan >= 2
                % #1 Window
                peakInfo{1, 1} = sprintf('[%.1f, %.1f]', ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.peaks{self.appParams.activePeak}.raw.wvls(1), ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.peaks{self.appParams.activePeak}.raw.wvls(end));
                % #2 Correlation
                peakInfo{2, 1} = round(self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.peaks{self.appParams.activePeak}.raw.corrRho*1000)/1000;
                % #3 Peak Location
                peakInfo{3, 1} = round(self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.peaks{self.appParams.activePeak}.raw.peakWvl*10)/10;
                % #4 Difference
                if self.appParams.activeScan >= 3
                    previousLoc = self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 2}.peaks{self.appParams.activePeak}.raw.peakWvl;
                    peakInfo{4, 2} = self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.peaks{self.appParams.activePeak}.raw.peakWvl - previousLoc;
                elseif self.appParams.activeScan == 2
                    peakInfo{4, 2} = 0;
                else
                    peakInfo{4, 2} = 'N/A';
                end
                % #5 Q
                peakInfo{5, 1} = 'N/A';
            end
            
            % Next Peak Info
            peakInfo(:, 3) = {'N/A'};
            if self.appParams.activeScan < self.lastScanNumber
                % #1 Window
                peakInfo{1, 3} = sprintf('[%.1f, %.1f]', ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan + 1}.peaks{self.appParams.activePeak}.raw.wvls(1), ...
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan + 1}.peaks{self.appParams.activePeak}.raw.wvls(end));
                % #2 Correlation
                peakInfo{2, 3} = round(self.dataset{self.appParams.activeChannel, self.appParams.activeScan + 1}.peaks{self.appParams.activePeak}.raw.corrRho*1000)/1000;
                % #3 Peak Location
                peakInfo{3, 3} = round(self.dataset{self.appParams.activeChannel, self.appParams.activeScan + 1}.peaks{self.appParams.activePeak}.raw.peakWvl*10)/10;
                % #4 Difference
                previousLoc = self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.peaks{self.appParams.activePeak}.raw.peakWvl;
                peakInfo{4, 2} = self.dataset{self.appParams.activeChannel, self.appParams.activeScan + 1}.peaks{self.appParams.activePeak}.raw.peakWvl - previousLoc;
                % #5 Q
                peakInfo{5, 1} = 'N/A';
            end
            set(self.gui.panelPeakTable, 'Data', peakInfo);
        end
        
        % dataset menu callbacks
        function self = mainMenuDatasetClose_Callback (self, hObject, eventData)
            % leave gui objects but delete all data
            self.initializeDatasetProperties();
%             msgbox('mainMenuDatasetClose_Callback -- shon needs to implement');
%             return
        end
        function self = mainMenuDatasetPreprocess_Callback (self, hObject, eventData)
            % prompt user for dataset directory
            self.path.datasetDir = uigetdir(self.path.datasetDir, 'Dataset folder');
            % return if user cancelled
            if self.path.datasetDir == 0 %user pressed cancel
                return
            end
            % check for '\' at end, append
            if ~strcmpi (self.path.datasetDir(end), '\')
                self.path.datasetDir = strcat(self.path.datasetDir, '\');
            end;            
            fileType = strcat(self.path.datasetDir, 'Scan*.mat');
            list = dir(fileType);
            % determine how many scan files are in the directory
            self.lastScanNumber = length(list);
            % determine starting scan, assume first scan file = Scan1.mat
            self.firstScanNumber = 1;
            % update GUI cropping feature
            set(self.gui.peakTrackingFigCropLB, 'String', num2str(self.firstScanNumber));
            set(self.gui.peakTrackingFigCropUB, 'String', num2str(self.lastScanNumber));
            % create filename
            filename = strcat(self.path.datasetDir, 'Scan', num2str(self.firstScanNumber), '.mat');
            while ~exist(filename, 'file')
                msg = strcat('File ', filename, ' does not exist. ');
                self.firstScanNumber = self.firstScanNumber + 1;
                filename = strcat(self.path.datasetDir, 'Scan', num2str(self.firstScanNumber), '.mat');
                msg = strcat(msg, 'Checking for file ', filename);
                disp(msg);
            end
            self.preProcessDataset();
        end
        function self = mainMenuDatasetSaveAnalysis_Callback (self, hObject, eventData)
            % save data
            self.saveAnalysis();
            msg = strcat('Analysis saved in: ', self.path.analysisFile);
            msgbox(msg);
        end
        function self = mainMenuDatasetReportQs_Callback (self, hObject, eventData)
            msgbox('mainMenuDatasetReportQs_Callback -- shon needs to implement');
            return
        end
        
        % channel menu callbacks
        function self = menuBarChannelPreferences_Callback (self, hObject, eventData)
            self.settingsPopup('menuBarChannel');
        end
        
        % peak menu callbacks
        function self = menuBarPeakPreferences_Callback (self, hObject, eventData)
            self.settingsPopup('menuBarPeak');
        end
        
        % analysis scripts menu callbacks
        function self = menuBarAnalysisScripts_Callback (self, hObject, eventData, scriptName)
            % execute script
            %            eval('scriptName');
            % shons note: need to figure out how to pass self obj and return it
            self = feval(scriptName, self);
        end
        
        %% Settings popup window
        function self = settingsPopup(self, structName)
            %            numParams = length(fieldnames(self.(structName)));
            numParams = length(fieldnames(self.(structName)));
            self.gui.settingsPopup.mainWindowHandle = dialog(...
                'WindowStyle', 'modal', ...
                'Units', 'normalized', ...
                'Resize', 'on', ...
                'Position', [.45 .75-.05*numParams .3 .03*numParams]);
            % get list of all the indices in struct
            fields = fieldnames(self.(structName));
            % convert struct to cell array
            cellArray = struct2cell(self.(structName));
            
            % loop through params and create gui elements
            for ii = 1:length(fieldnames(self.(structName)))
                size = length(fieldnames(self.(structName)));
                % create field name
                self.gui.settingsPopup.paramName(ii) = uicontrol(...
                    'Parent', self.gui.settingsPopup.mainWindowHandle, ...
                    'Style', 'text', ...
                    'Units', 'normalized', ...
                    'Position', [.005 .95- 0.9*ii/size .49 1/(2*numParams)], ...
                    'HorizontalAlignment', 'right', ...
                    'FontSize', 10, ...
                    'String', fields(ii));
                
                % field value (typed)
                if (isnumeric(cellArray{ii}))
                    paramType = 'numeric';
                elseif (ischar(cellArray{ii}))
                    paramType = 'string';
                elseif (islogical(cellArray{ii}))
                    paramType = 'logical';
                end
                
                if strcmp(paramType, 'logical')
                    % create a checkbox
                    self.gui.settingsPopup.paramVal(ii) = uicontrol(...
                        'Parent', self.gui.settingsPopup.mainWindowHandle, ...
                        'Style', 'checkbox', ...
                        'Value', self.(structName).(fields{ii}),...
                        'Units', 'normalized', ...
                        'Position', [.51 .95- 0.9*ii/size .15 1/(2*numParams)], ...
                        'Callback', {@self.settingsPopupValue, structName, ii});
                else % create a string box for everything else
                    self.gui.settingsPopup.paramVal(ii) = uicontrol(...
                        'Parent', self.gui.settingsPopup.mainWindowHandle, ...
                        'Style', 'edit', ...
                        'Units', 'normalized', ...
                        'Position', [.51 .95- 0.9*ii/size .15 1/(2*numParams)], ... %'Position', [.45 .95-ii/10 .3 .08], ...
                        'HorizontalAlignment', 'left', ...
                        'FontSize', 10, ...
                        'String', cellArray{ii},...
                        'Callback', {@self.settingsPopupValue, structName, ii});
                end
            end
            
            % done button
            self.gui.doneButton = uicontrol(...
                'Parent', self.gui.settingsPopup.mainWindowHandle, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [.8 .05 .1 1/(1.5*numParams)], ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 10, ...
                'String', 'Done',...
                'Callback', @self.settingsPopupDone);
            
            movegui(self.gui.settingsPopup.mainWindowHandle, 'center');
        end
        
        % settingsPopupVal callback
        function self = settingsPopupValue(self, hObject, eventData, structName, ii)
            % Need to do some type checking here...
            % get list of struct fields
            fields = fieldnames(self.(structName));
            
            % field value (typed)
            if islogical(self.(structName).(fields{ii}))
                % get value
                newVal = get(hObject, 'Value');
                self.(structName).(fields{ii}) = logical(newVal);
            elseif isnumeric(self.(structName).(fields{ii}))
                % get value
                newVal = get(hObject, 'String');
                self.(structName).(fields{ii}) = str2double(newVal);
            else % assume string
                % get value
                newVal = get(hObject, 'String');
                self.(structName).(fields{ii}) = newVal;
            end
        end
        
        function changePeakTypeInfo(self, isPeak)
            
        end
        
        %% scanline correlation
        function scanlineCorrelation(self)
            % correlates this and previous scanlines
            % assumes wavelength vectors match
            % ensure not the first scanline
            if self.appParams.activeScan > self.firstScanNumber
                % check if wavelengh vectors match
                thisScanWvlSize = length(self.dataset{self.appParams.activeChannel, self.appParams.activeScan - 1}.wvl);
                nextScanWvlSize = length(self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.wvl);
                if thisScanWvlSize == nextScanWvlSize
                    % correlate power values
                    [rho,pval] = corr(...
                        self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.pwr,...
                        self.dataset{self.appParams.activeChannel, self.appParams.activeScan-1}.pwr);
                    % assign to object property
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.corrRho = rho;
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.corrPval = pval;
                else
                    % error -- cannot make correlation
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.corrRho = inf;
                    self.dataset{self.appParams.activeChannel, self.appParams.activeScan}.corrPval = inf;
                end
            end
        end
        
        function peaksCorrelation(self)
            for scanNumber = self.appParams.activeScan - 1:self.appParams.activeScan + 1
                if scanNumber > self.firstScanNumber && scanNumber <= self.lastScanNumber
                    % Raw Peak Correlation
                    thisPwr = self.dataset{self.appParams.activeChannel, scanNumber}.peaks{self.appParams.activePeak}.raw.pwrs;
                    previousPwr = self.dataset{self.appParams.activeChannel, scanNumber - 1}.peaks{self.appParams.activePeak}.raw.pwrs;
                    thisSize = length(self.dataset{self.appParams.activeChannel, scanNumber}.peaks{self.appParams.activePeak}.raw.wvls);
                    previousSize = length(self.dataset{self.appParams.activeChannel, scanNumber - 1}.peaks{self.appParams.activePeak}.raw.wvls);
                    if abs(thisSize - previousSize) <= 2
                        smallSize = min(thisSize, previousSize);
                        thisPwr = thisPwr(1:smallSize);
                        previousPwr = previousPwr(1:smallSize);
                        thisSize = smallSize;
                        previousSize = smallSize;
                    end
                    if thisSize == previousSize
                        % correlate power values
                        [rho,pval] = corr(thisPwr, previousPwr);
                        % assign to object property
                        self.dataset{self.appParams.activeChannel, scanNumber}.peaks{self.appParams.activePeak}.raw.corrRho = rho;
                        self.dataset{self.appParams.activeChannel, scanNumber}.peaks{self.appParams.activePeak}.raw.corrPval = pval;
                    end
                end
            end
        end
        
    end % methods
    
    methods (Static)
        % close settings window popup
        function settingsPopupDone(hObject, eventData)
            uiresume;
            delete(get(hObject, 'parent'));
            %            delete(self.gui.settingsPopup);
        end
    end % static methods
    
end
