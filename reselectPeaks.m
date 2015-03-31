function obj = reselectPeaks(obj)

% delete all peakData objects for scanline and re-create from scratch
if exist('obj.dataset{obj.activeChannel}(obj.activeScan).peakData', 'class')
    clear obj.dataset{obj.activeChannel}(obj.activeScan).peakData;
end

% main figure window
obj.gui.reselectPeaksPopup.mainWindow = figure(...
    'Unit', 'normalized', ...
    'Position', [0, 0, 0.68, 0.85],...
    'Menu', 'None',...
    'Name', sprintf('Reselect peaks for scan %d', obj.activeScan),...
    'WindowStyle', 'normal',...  % normal , modal, docked.
    'Visible', 'off',...
    'NumberTitle', 'off',...
    'CloseRequestFcn', {@closeWindow});

% main panel
obj.gui.reselectPeaksPopup.mainPanel = uipanel(...
    'parent', obj.gui.reselectPeaksPopup.mainWindow,...
    'BackgroundColor',[0.9 0.9 0.9],...
    'Visible','on',...
    'Units', 'normalized', ...
    'Position', [.005, .005, .990, .990]);

% title string
obj.gui.reselectPeaksPopup.stringTitle = uicontrol(...
    'Parent', obj.gui.reselectPeaksPopup.mainPanel,...
    'Style', 'text',...
    'HorizontalAlignment','center',...
    'BackgroundColor',[0.9 0.9 0.9 ],...
    'Units', 'normalized',...
    'String','Reselect Peaks',...
    'FontSize', 13, ...
    'FontWeight','bold',...
    'Position', [.3, .95, .4, .035]);

% save and close button
obj.gui.reselectPeaksPopup.save_and_close_button = uicontrol(...
    'parent', obj.gui.reselectPeaksPopup.mainPanel,...
    'Style', 'pushbutton',...
    'units', 'normalized',...
    'String', 'SAVE & CLOSE',...
    'FontWeight', 'bold', ...
    'Enable', 'on',...
    'Position', [0.73, 0.87, 0.12, 0.05],...
    'Callback', {@save_and_close_cb, obj});

%% Generate Axes
plotPanel_w = 0.62;
plotPanel_h = 0.85;
% axes panel
obj.gui.reselectPeaksPopup.plotPanel = uipanel(...
    'parent', obj.gui.reselectPeaksPopup.mainPanel,...
    'Title', 'Sweep Data', ...
    'FontWeight', 'bold', ...
    'FontSize', 11, ...
    'BackgroundColor', [0.9, 0.9, 0.9],...
    'Visible', 'on',...
    'Units', 'normalized',...
    'Position', [0.01, 0.01, plotPanel_w, plotPanel_h]);

for i = 1:obj.numberOfChannels
    % draw axes
    obj.gui.reselectPeaksPopup.sweepScanSubplot(i)= subplot(obj.numberOfChannels, 1, i);
    set(obj.gui.reselectPeaksPopup.sweepScanSubplot(i), ...
        'Parent', obj.gui.reselectPeaksPopup.plotPanel, ...
        'Units', 'normalized');
    axePosition = get(obj.gui.reselectPeaksPopup.sweepScanSubplot(i), 'Position');
    axePosition(1) = 0.08;
    axePosition(2) = 1.01 - axePosition(4)*1.5*i;
    set(obj.gui.reselectPeaksPopup.sweepScanSubplot(i), ...
        'Position', axePosition)
    xlabel('Wavelength [nm]');
    ylabel('Power [dBm]');
    title(strcat(['Channel ', num2str(i)]));
   
    % checkbox for resonant peak vs. null
    obj.gui.reselectPeaksPopup.maximaCheckBox(i) = uicontrol(...
        'Parent', obj.gui.reselectPeaksPopup.plotPanel,...
        'Style', 'checkbox',...
        'units', 'normalized',...
        'position', [.87, axePosition(2) + axePosition(4)*0.81, .12, axePosition(4)*0.17],...
        'string', 'Choose Maxima',...
        'Enable', 'on',...
        'callback', {@peak_button_cb, i});
    
    % start button for peak selection
    obj.gui.reselectPeaksPopup.startButton(i) = uicontrol(...
        'Parent', obj.gui.reselectPeaksPopup.plotPanel,...
        'Style', 'pushbutton',...
        'units', 'normalized',...
        'position', [.87, axePosition(2) + axePosition(4)*0.66, .12, axePosition(4)*0.17],...
        'string', 'Start',...
        'Enable', 'on',...
        'callback', {@start_button_cb, obj, i});
    
    % done button for peak selection
    obj.gui.reselectPeaksPopup.doneButton(i) = uicontrol(...
        'Parent', obj.gui.reselectPeaksPopup.plotPanel,...
        'Style', 'pushbutton',...
        'units', 'normalized',...
        'position', [.87, axePosition(2) + axePosition(4)*0.48, .12, axePosition(4)*0.17],...
        'string', 'Done',...
        'userData', false, ...
        'Enable', 'off', ...
        'callback', {@done_button_cb, obj, i});
    
    % Table to show selected wvls
    PeakLocations = {};
    obj.gui.reselectPeaksPopup.peaksTable(i) = uitable(...
        'Parent', obj.gui.reselectPeaksPopup.plotPanel,...
        'ColumnName', {'Wvl', 'LeftInd', 'RightInd'},...
        'ColumnFormat',{'char', 'char', 'char'},...
        'ColumnEditable', false,...
        'Units','normalized',...
        'Position', [0.87, axePosition(2)-0.02, 0.12, axePosition(4)*0.6],...
        'Data', PeakLocations,...
        'FontSize', 9,...
        'ColumnWidth', {50},...
        'CellEditCallback',{@cell_edit_cb, i},...
        'CellSelectionCallback', {@cell_sel_cb, i},...
        'Enable', 'on');
end

movegui(obj.gui.reselectPeaksPopup.mainWindow, 'center');
set(obj.gui.reselectPeaksPopup.mainWindow, 'Visible', 'on');

end % ends reselectPeaks Popup

%% SELECT PEAKS FROM PLOT
function peak_selection(obj, index)
PeakInfo = {};

isMaxima = get(obj.gui.reselectPeaksPopup.maximaCheckBox(index), 'Value');
defaultWindowSize = [2, 2]; %nm

% Delete the previous (if any) peak selection
delete(findobj(obj.gui.reselectPeaksPopup.sweepScanSubplot(index), 'Marker', '+'));
set(obj.gui.reselectPeaksPopup.peaksTable(index), 'Data', {});

%this is not good: can't reset peak locations.
dataObj = get(obj.gui.reselectPeaksPopup.sweepScanSubplot(index),'Children');
wvlVals = get(dataObj, 'XData');
pwrVals = get(dataObj, 'YData');
xrange = max(wvlVals) - min(wvlVals);
tol = xrange/100;
n = 0;
hold(obj.gui.reselectPeaksPopup.sweepScanSubplot(index), 'on');
finish = false;
%PeakInfo = cell(10,2); % preallocate for speed, assume less than 10 peaks selected
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
            plot(obj.gui.reselectPeaksPopup.sweepScanSubplot(index), wvlPeak, pwrPeak, 'r+'); % make a red-x at point
            n = n + 1;
            
            % Set window size for the selected peak ------------
            windowSelF = figure(...
                'Unit', 'normalized', ...
                'Position', [0, 0, 0.33, 0.33],...
                'Menu', 'None',...
                'Name', 'Please Specify Window Size',...
                'NumberTitle', 'off');
            windowSelA = axes('Parent', windowSelF);
            windowLeftIndex = find(wvlVals - (wvlPeak - defaultWindowSize(1)) <= 0);
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
            pause(1)
            newWindow = getrect(windowSelA);
            windowLeft = newWindow(1);
            windowSize = newWindow(3);
            windowRight = windowLeft + windowSize;
            windowLeftIndex = find(wvlVals - windowLeft <= 0);
            windowLeftIndex = windowLeftIndex(end);
            windowLeft = wvlVals(windowLeftIndex);
            windowRightIndex = find(wvlVals - windowRight <= 0);
            windowRightIndex = windowRightIndex(end);
            windowRight = wvlVals(windowRightIndex);
            close(windowSelF);
            % ---------------------------------------------------
            
            PeakInfo{n, 1} = wvlPeak;
            PeakInfo{n, 2} = windowLeftIndex;
            PeakInfo{n, 3} = windowRightIndex;
            set(obj.gui.reselectPeaksPopup.peaksTable(index), 'Data', PeakInfo);
        end
    elseif (button == 2 || button == 3)  %user right or middle mouse click
        finish = true;
    end
end
hold(obj.gui.reselectPeaksPopup.sweepScanSubplot(index), 'off');
end

%% CALLBACK FUNCTIONS
function closeWindow(hObject, ~)
delete(hObject);
end

function peak_button_cb(hObject, ~, index)
% since the peakData objects may not be created yet (not until close, keep
% this information in the object's 'userData'
isPeak = get(hObject, 'UserData'); % for all channels
%isPeak = get(obj.gui.reselectPeaksPopup.maximaCheckBox, 'UserData'); % for all channels
isChecked = get(hObject, 'Value');
if isChecked % set flags for positive peak tracking in device object
    isPeak(index) = true;
else % is resonant null
    isPeak(index) = false;
end
% write userData back to object
set(hObject, 'UserData', isPeak);
end

function start_button_cb(hObject, ~, obj, index)
set(hObject, 'Enable', 'off'); % disable the start button that was pressed
set(obj.gui.reselectPeaksPopup.doneButton(index), 'Enable', 'on');
peak_selection(obj, index);
end

function done_button_cb(hObject, ~, obj, index)
% save wvls (meters) of selected peaks to peak objects
% also find the min/max of selected peaks from all detectors and save in
% peak object as start and stop wvls

set(obj.gui.reselectPeaksPopup.startButton(index), 'Enable', 'on'); % enable start button again
peakInfo = get(obj.gui.reselectPeaksPopup.peaksTable(index), 'data');
wvl_data = cell2mat(peakInfo(:, 1)); % get wvl data from table
window_data(:, 1) = cell2mat(peakInfo(:, 2));
window_data(:, 2) = cell2mat(peakInfo(:, 3));

% TODO: get window LB and UB
windowLBIndex = 0;
windowUBIndex = 0;

% get isPeak (or not)
isPeak = get(obj.gui.reselectPeaksPopup.maximaCheckBox, 'UserData');

% save data to the device object
for ii = 1:length(wvl_data)
%     % shons note -- I decided to delete all peakData objects at start and recreate
%     if exist('obj.dataset{obj.activeChannel}(obj.activeScan).peakData{ii}', 'class')
%         % object already exists, just overwrite the data
%     else
%         % create object and write data
%     end
    obj.dataset{obj.activeChannel}(obj.activeScan).peakData{ii} = peakClass(wvl_data(ii), windowLBIndex, windowUBIndex, isPeak(index));
end

set(hObject, 'Enable', 'off'); % disable done button that was pushed

end

function save_and_close_cb(~, ~, obj)
close(obj.gui.reselectPeaksPopup.mainWindow);
obj.gui.popup_peaks = [];
end

function cell_edit_cb(hObject, eventdata, index)
end

function cell_sel_cb(hObject, eventdata, index)
end