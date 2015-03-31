function peakResults = selectPeaks(scanFileData)
% shon/vince 28 nov 2014
% inputs
%   scanFileData.deviceInfo
%               .params
%               .scanResults
%               .timeStamp

% outputs:
%   peakResults (in the format below)
%
% NOTES: for reference only (copied from deviceClass.m)
%     peakResults = struct(...
%         'isPeak', self.isPeak, ...
%         'peakWvl', cell(size(self.peakLocations)), ...
%         'wvlWindow', cell(size(self.PeakTrackWindows)));
%     for d = 1:self.NumOfDetectors
%         for p = 1:length(self.peakLocations{d})
%             peakResults.peakWvl{d}{p} = self.peakLocations{d}{p}(self.ScanNumber);
%             peakResults.wvlWindow{d}{p} = self.ThisSweep(d).wvl(self.PeakTrackWindows{d}{p});
%         end
%     end

% Get the number of detectors
% obj.isPeak = zeros(1, numDetectors);
obj.scanFileData = scanFileData;
numDetectors = length(obj.scanFileData.scanResults);
peakResults = struct(...
        'isPeak', 0, ...
        'peakWvl', 0, ...
        'wvlWindow', 0);
    peakResults.isPeak = zeros(1, numDetectors);
    peakResults.peakWvl = cell(1, numDetectors);
    peakResults.wvlWindow = cell(1, numDetectors);
    
%     obj.isPeak = zeros(1, numDetectors);
%     obj.peakWvl = cell(1, numDetectors);
%     obj.wvlWindow = cell(1, numDetectors);

obj.gui.mainWindow = figure(...
    'Unit', 'normalized', ...
    'Position', [0, 0, 0.68, 0.85],...
    'Menu', 'None',...
    'Name', 'Peak selection',...
    'WindowStyle', 'normal',...  % normal , modal, docked.
    'Visible', 'off',...
    'NumberTitle', 'off',...
    'CloseRequestFcn', {@closeWindow});

% main panel
obj.gui.mainPanel = uipanel(...
    'parent', obj.gui.mainWindow,...
    'BackgroundColor',[0.9 0.9 0.9],...
    'Visible','on',...
    'Units', 'normalized', ...
    'Position', [.005, .005, .990, .990]);

% save and close button
obj.gui.save_and_close_button = uicontrol(...
    'parent', obj.gui.mainPanel,...
    'Style', 'pushbutton',...
    'units', 'normalized',...
    'String', 'Save and Close',...
    'Enable', 'on',...
    'Position', [0.9, 0.95, 0.08, 0.03],...
    'Callback', {@save_and_close_cb});

%% Generate Axes
for i = 1:numDetectors
    % draw axes
    obj.gui.sweepScanSubplot(i)= subplot(numDetectors, 1, i);
    set(obj.gui.sweepScanSubplot(i), ...
        'Parent', obj.gui.mainPanel, ...
        'Units', 'normalized');
    axePosition = get(obj.gui.sweepScanSubplot(i), 'Position');
    axePosition(1) = 0.08;
    axePosition(2) = 1.01 - axePosition(4)*1.5*i;
    set(obj.gui.sweepScanSubplot(i), ...
        'Position', axePosition)
    xlabel('Wavelength [nm]');
    ylabel('Power [dBm]');
    title(strcat(['Detector ', num2str(i)]));
   
    % checkbox for resonant peak vs. null
    obj.gui.maximaCheckBox(i) = uicontrol(...
        'Parent', obj.gui.mainPanel,...
        'Style', 'checkbox',...
        'units', 'normalized',...
        'position', [.87, axePosition(2) + axePosition(4)*0.81, .12, axePosition(4)*0.17],...
        'string', 'Choose Maxima',...
        'Enable', 'on',...
        'callback', {@peak_button_cb, i});
    
    % start button for peak selection
    obj.gui.startButton(i) = uicontrol(...
        'Parent', obj.gui.mainPanel,...
        'Style', 'pushbutton',...
        'units', 'normalized',...
        'position', [.87, axePosition(2) + axePosition(4)*0.66, .12, axePosition(4)*0.17],...
        'string', 'Start',...
        'Enable', 'on',...
        'callback', {@start_button_cb, i});
    
    % done button for peak selection
    obj.gui.doneButton(i) = uicontrol(...
        'Parent', obj.gui.mainPanel,...
        'Style', 'pushbutton',...
        'units', 'normalized',...
        'position', [.87, axePosition(2) + axePosition(4)*0.48, .12, axePosition(4)*0.17],...
        'string', 'Done',...
        'userData', false, ...
        'Enable', 'off', ...
        'callback', {@done_button_cb, i});
    
    % Table to show selected wvls
    peakLocations = {};
    obj.gui.peaksTable(i) = uitable(...
        'Parent', obj.gui.mainPanel,...
        'ColumnName', {'Wvl', 'LeftInd', 'RightInd'},...
        'ColumnFormat',{'char', 'char', 'char'},...
        'ColumnEditable', false,...
        'Units','normalized',...
        'Position', [0.87, axePosition(2)-0.02, 0.12, axePosition(4)*0.6],...
        'Data', peakLocations,...
        'FontSize', 9,...
        'ColumnWidth', {50},...
        'CellEditCallback',{@cell_edit_cb, i},...
        'CellSelectionCallback', {@cell_sel_cb, i},...
        'Enable', 'on');
end

% ************************ Plot data from scanfile ************************
scan = obj.scanFileData.scanResults; 
for d = 1:numDetectors
    scan1Wvl = scan(d).Data(:, 1);
    scan1Pwr = scan(d).Data(:, 2);
    plot(obj.gui.sweepScanSubplot(d), scan1Wvl(1:end-1), scan1Pwr(1:end-1));
    xlabel('Wavelength [nm]');
    ylabel('Power [dBm]');
    title(strcat(['Detector ', num2str(d)]));
end
% ************************ Plot data from scanfile ************************

movegui(obj.gui.mainWindow, 'center');
set(obj.gui.mainWindow, 'Visible', 'on');

% store info in UserData of obj.gui.mainPanel object and return
% results = get(obj.gui.mainPanel, 'UserData');
uiwait(obj.gui.mainWindow)

    
%     peakResults.isPeak = obj.isPeak;
%     peakResults.peakWvl = obj.peakWvl;
%     peakResults.wvlWindow = obj.wvlWindow;
    
% for dd = numDetectors
%     if any(dd == includedChannel)
%         
%     end
% end
% end % ends SelectPeaks Popup

%% SELECT PEAKS FROM PLOT
function peak_selection(index) % --- Vince 2013
PeakInfo = {};

isMaxima = get(obj.gui.maximaCheckBox(index), 'Value');
defaultWindowSize = [2, 2]; %nm

% Delete the previous (if any) peak selection
delete(findobj(obj.gui.sweepScanSubplot(index), 'Marker', '+'));
set(obj.gui.peaksTable(index), 'Data', {});

%this is not good: can't reset peak locations.
dataObj = get(obj.gui.sweepScanSubplot(index),'Children');
wvlVals = get(dataObj(end), 'XData');
pwrVals = get(dataObj(end), 'YData');
% WinPoints = 5/(wvlVals(2)-wvlVals(1)); % window/step = num of elements: for a 2nm window;
xrange = max(wvlVals) - min(wvlVals);
tol = xrange/100;
n = 0;
hold(obj.gui.sweepScanSubplot(index), 'on');
finish = false;
PeakInfo = cell(10,2); % preallocate for speed, assume less than 10 peaks selected
while (~finish)
    [xsel, ysel, button] = ginput(1);
    % get x,y coord of mouse cursor
    % button is an integer indicating which mouse buttons you pressed
    % (1 for left, 2 for middle, 3 for right)
    if (button == 1) %user - left-click
        boundary = ...
            xsel <= max(wvlVals) && xsel >= min(wvlVals) && ...
            ysel <= max(pwrVals) && ysel >= min(pwrVals);
        if (boundary) % Process data only when user click with in the proper axes
            % Limit the range of wavelength selection
            wvlVals_filter = wvlVals(abs(wvlVals - xsel) <= tol);
            pwrVals_filter = pwrVals(abs(wvlVals - xsel) <= tol);
            
            % Find the peak power value within the limited range above
            if isMaxima
                [pwrPeak, ind] = max(pwrVals_filter); % look for index of min y in range
            else
                [pwrPeak, ind] = min(pwrVals_filter); % look for index of min y in range
            end
            wvlPeak = wvlVals_filter(ind);
            
            % update plot /w X on selected point
            plot(obj.gui.sweepScanSubplot(index), wvlPeak, pwrPeak, 'r+'); % make a red-x at point
            n = n + 1;
            if n > 10
                error('Cannot select more than 10 peaks');
            end
            
            % Set window size for the selected peak ------------
            windowSelF = figure(...
                'Unit', 'normalized', ...
                'Position', [0, 0, 0.33, 0.33],...
                'Menu', 'None',...
                'Name', 'Please Specify Window Size',...
                'NumberTitle', 'off');
            windowSelA = axes('Parent', windowSelF);
            windowLeftIndex = find(wvlVals - (wvlPeak - defaultWindowSize(1)) <= 0);
            if isempty(windowLeftIndex)
                windowLeftIndex = 1;
            end
            windowLeftIndex = windowLeftIndex(end);
            windowRightIndex = find(wvlVals - (wvlPeak + defaultWindowSize(1)) <= 0);
            windowRightIndex = windowRightIndex(end);
            defaultWvlWindow = wvlVals(windowLeftIndex:windowRightIndex);
            defaultPwrWindow = pwrVals(windowLeftIndex:windowRightIndex);
            plot(windowSelA, defaultWvlWindow, defaultPwrWindow, 'b');
            hold(windowSelA, 'on')
            plot(windowSelA, wvlPeak, pwrPeak, 'r+');
            hold(windowSelA, 'off')
            movegui(windowSelF, 'center')
            
            % Set a default value for window size
            windowSize = 3;
            % -----------------------------------
            pause(0.2)
            validWindow = false;
            while ~validWindow
                newWindow = getrect(windowSelA);
                windowSize = newWindow(3);
                wl = newWindow(1);
                wr = wl + windowSize;
                validWindow = (wl < wvlPeak && wvlPeak < wr);
            end
            windowLeft = wvlPeak - windowSize/2;
            windowRight = wvlPeak + windowSize/2;
            windowLeftIndex = find(wvlVals - windowLeft <= 0);
            if isempty(windowLeftIndex)
                windowLeftIndex = 1;
            else
                windowLeftIndex = windowLeftIndex(end);
            end
            windowRightIndex = find(wvlVals - windowRight <= 0);
            windowRightIndex = windowRightIndex(end);
            try
                close(windowSelF);
            end
            % ---------------------------------------------------
            
            PeakInfo{n, 1} = wvlPeak;
            PeakInfo{n, 2} = windowLeftIndex;
            PeakInfo{n, 3} = windowRightIndex;
            set(obj.gui.peaksTable(index), 'Data', PeakInfo);
        end
    elseif (button == 2 || button == 3)  %user right or middle mouse click
        finish = true;
    end
end
hold(obj.gui.sweepScanSubplot(index), 'off');
end

%% CALLBACK FUNCTIONS
function closeWindow(hObject, ~)
delete(hObject);
end

function peak_button_cb(hObject, ~, index)
isChecked = get(hObject, 'Value');
if isChecked % set flags for positive peak tracking in device object
    obj.isPeak(index) = 1; % peak, not null
else % clear settings in device object
    obj.isPeak(index) = 0; % resonant null, not peak
end
end

function start_button_cb(hObject, ~, index)
set(hObject, 'Enable', 'off'); % disable the start button that was pressed
set(obj.gui.doneButton(index), 'Enable', 'on');
peak_selection(index);
end

function done_button_cb(hObject, ~, index)
% save wvls (meters) of selected peaks to device object
% also find the min/max of selected peaks from all detectors and save in
% device object as start and stop wvls

set(obj.gui.startButton(index), 'Enable', 'on'); % enable start button again
peakInfo = get(obj.gui.peaksTable(index), 'data');
wvl_data = cell2mat(peakInfo(:, 1)); % get wvl data from table
window_data(:, 1) = cell2mat(peakInfo(:, 2));
window_data(:, 2) = cell2mat(peakInfo(:, 3));
% find min and max of data
data_min = min(wvl_data);
data_max = max(wvl_data);

scanData = obj.scanFileData.scanResults;
peakResults.isPeak(index) = get(obj.gui.maximaCheckBox(index), 'Value');
for ww = 1:length(wvl_data)
    peakResults.peakWvl{index}{ww} = wvl_data(ww);
    wvlLeft = scanData(index).Data(window_data(ww, 1), 1);
    wvlRight = scanData(index).Data(window_data(ww, 2), 1);
    peakResults.wvlWindow{index}{ww} = wvlRight - wvlLeft;
end

% determine if overall min/max is within data and set if so
% min (start wvl)
% if isempty(obj.getProp('StartWvl')) % device property not set yet
%     obj.setProp('StartWvl', data_min);
% elseif data_min < obj.getProp('StartWvl') % current start higher than lowest selected peak
%     obj.setProp('StartWvl', data_min);
% end
% % max (stop wvl)
% if isempty(obj.getProp('StopWvl'))
%     obj.setProp('StopWvl', data_max);
% elseif data_max > obj.getProp('StopWvl')
%     obj.setProp('StopWvl', data_max);
% end

set(hObject, 'Enable', 'off'); % disable done button that was pushed

% enable selectPeakTracking window button
% set(obj.gui.peakTrackWindowButton(index), 'Enable', 'on');
end

function save_and_close_cb(hObject, eventData)
% need to return data to appClass
close(obj.gui.mainWindow);
end


function selectPeakTrackWindow_cb(hObject, ~, index)
% pop-up a new window with X nm's of range on either side of the FIRST
% selected peak. After the window is selected, pop-up a new window w/ the
% SECOND peak, etc. until all the selected peaks have tracking windows

% TODO: add a default xRange to the default AppSettigs and load user's pref
xRange_nm = 2; % in nm

% convert nm to # of points (need StepWvl, also in nm)
StepWvl = obj.instr.laser.getProp('StepWvl');
xRange_pts = xRange_nm/StepWvl;

% get the number of peak locations selected for this detector
peakLocations = get(obj.gui.peaksTable(index), 'Data');
numPeaks = length(peakLocations);
end

function cell_edit_cb(hObject, eventdata, index)
end

function cell_sel_cb(hObject, eventdata, index)
end

end