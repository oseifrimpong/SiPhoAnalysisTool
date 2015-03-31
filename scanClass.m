classdef scanClass < handle
    %scanClass Summary of this class goes here
    %   the scan class contains the data and methods that act on the entire
    %   scanline of data (entire wavelength range). If an assay has 100
    %   scans, then there will be 100 instances of this class (one object
    %   for each scan)
    
    %% class properties
    properties
        % table properties
        legend; % previous and next colors -- maybe this should be on a legend instead of a table
        DCOffset; % global 'dc offset' between scanlines
%        reagent; % reagent at the time of scan
        temp; % recorded temperature at time of scan
        timeStamp; % scan line time stamp
        relativeTime;
        excludeScan; % flag that determines whether or not peak is plotted in tracked peaks window
        corrRho; % pairwise linear correlation coefficients
        corrPval; % correlation p value
%        tag; % refrence, functional, or acetylene
        % scan data
        % this object keeps the data for 1 detectors for 1 scan
        
        isPeak;
        wvl; % scanline wavelength array
        pwr; % scaline power values array
        params; % scanline params
        
        % peak data
        peaks = {};
        %where length = number of peaks and p1, p2,... are of class
        %'peakClass'  p1 = peakClass;
        
        %note for shon: add tag for dataset : to stich multiple datasets
        %together
        DEBUG; 
        defaultPeakWindowSize; %window size for popu up window (reselect peak)
            %gets loaded from menuBarPeak.peakWindowSize  (2nm default
            %value)
        
        % Should know number of peaks
        numOfPeaks;
        peakLocation;
    end
    
    %% methods
    methods
        %% constructor
        function self = scanClass (varargin)
          
           
            if nargin == 0 %create empty vectors if no input arguments:
                %This should not be the case, there should be data at the
                errordlg('No Scan File is loaded!', 'ERROR')
                return;
            elseif nargin == 4 % case where no data has been scrubbed
                self.wvl = varargin{1};
                self.pwr = varargin{2};
                self.params = varargin{3};
                self.excludeScan = false ; %default values: include every scan
            elseif nargin >= 6;
                %case where there is prelim peak value
                self.wvl = varargin{1};
                self.pwr = varargin{2};
                self.DCOffset = mean(self.pwr);
                self.params = varargin{3};
                self.timeStamp = varargin{4};
                self.excludeScan = false ; %default values: include every scan.
                self.updateScanInfo(varargin{5});
                self.defaultPeakWindowSize = varargin{6}; % nm
            end

            self.DEBUG = 0; %applcass should set it to 1 if DEBUG mode
            
%            self.tag = ''; % default value
        end % Constructor
        
        %% peak class creation
        function self = createPeakObject(self)
                % Initiate peak object
                self.peaks = cell(self.numOfPeaks, 1);
                % Create "isPeak" information for each peak - Vince
                self.isPeak = self.isPeak*ones(self.numOfPeaks, 1);
                % -----------------------------------------
                for pp = 1:self.numOfPeaks
                    peakInd = find(self.wvl - self.peakLocation(pp) <= 0);
                    if isempty(peakInd)
                        peakInd = 1;
                    end
                    peakInd = peakInd(end);
                    leftWvl = self.peakLocation(pp) - self.defaultPeakWindowSize{pp}/2;
                    leftIndex = find(self.wvl -  leftWvl >= 0);
                    leftIndex = leftIndex(1);
                    rightWvl = self.peakLocation(pp) + self.defaultPeakWindowSize{pp}/2;
                    rightIndex = find(self.wvl -  rightWvl <= 0);
                    rightIndex = rightIndex(end);
                    
                    if self.DEBUG
                    disp('CreatePeakObject debug ---------')
                        disp(strcat('peak',pp,'/',num2str(self.numOfPeaks)));
                        disp(strcat('peak index: ',num2str(peakInd(end)))); 
                        disp(strcat('self.isPeak=',num2str(self.isPeak))); %this is the same for all peaks
                        disp(strcat('Peak Wvl = ',num2str(self.wvl(peakInd(end)))));
                        disp(strcat('Peak Pwr = ',num2str(self.pwr(peakInd(end)))));
                    end
                    %if different or every peak (not implemented); 'isPeak', self.isPeak(pp), ...                  
                    peakInfo = struct(...
                        'isPeak', self.isPeak(pp), ...
                        'peakWvl', self.wvl(peakInd), ...
                        'peakPwr', self.pwr(peakInd), ...
                        'wvls', self.wvl(leftIndex:rightIndex), ...
                        'pwrs', self.pwr(leftIndex:rightIndex));
                    self.peaks{pp} = peakClass(peakInfo);
                    self.peaks{pp}.DEBUG = self.DEBUG; 
                end
        end % function createPeakObject
        
                
        function refineWindowSize = reselectPeak(self, activePeak, selWvl, selPwr, varargin)
            % User select peak - currently limit to 1 peak
            % varargin{1} is plot window size in [nm]: if not provided then figure is poped
            % up to select rectangle window size.
            if self.DEBUG
                disp('# input arguments');
                disp(num2str(nargin));
                disp('varargs: optional input {1}');
                disp(num2str(varargin{1}));
                
                disp('debug reselect peak:');
                disp(strcat('minWvl: ',num2str(min(self.wvl))));
                disp(strcat('maxWvl: ',num2str(max(self.wvl))));
                
            end
            %check if selected wvl/pwr is within scan range
            boundary = ...
                selWvl <= max(self.wvl) && selWvl >= min(self.wvl) && ...
                selPwr <= max(self.pwr) && selPwr >= min(self.pwr);
            if boundary % Only proceed when user click within valid boundary
                tol = (max(self.wvl) - min(self.wvl))/100;  %temp window 
                wvlFilter = self.wvl(abs(self.wvl - selWvl) <= tol);
                pwrFilter = self.pwr(abs(self.wvl - selWvl) <= tol);
                % Find the peak power value within the limited range above
                if self.isPeak(activePeak)
                    [pwrPeak, ind] = max(pwrFilter); % look for index of min y in range
                else
                    [pwrPeak, ind] = min(pwrFilter); % look for index of min y in range
                end
                wvlPeak = wvlFilter(ind);
                peakInd = find(self.wvl - wvlPeak <= 0);
                peakInd = peakInd(end);
                
                if nargin>=5
                   plot_window_size = varargin{1};
                else
                    if self.DEBUG
                        disp('popup window used defaultWindowSize - should not happen');
                    end
                    plot_window_size = self.defaultPeakWindowSize{pp}; 
                end
                % Popup to set window size
                    windowSelF = figure(...
                        'Unit', 'normalized', ...
                        'Position', [0, 0, 0.33, 0.33],...
                        'Menu', 'None',...
                        'Name', 'Please Specify Window Size',...
                        'NumberTitle', 'off');
                    windowSelA = axes('Parent', windowSelF);
                    windowLeftIndex = find(self.wvl - (wvlPeak - plot_window_size/2) <= 0);
                    if isempty(windowLeftIndex)
                        windowLeftIndex = 1;
                    else
                        windowLeftIndex = windowLeftIndex(end);
                    end
                    windowRightIndex = find(self.wvl - (wvlPeak + plot_window_size/2) <= 0);
                    windowRightIndex = windowRightIndex(end);
                    defaultWvlWindow = self.wvl(windowLeftIndex:windowRightIndex);
                    defaultPwrWindow = self.pwr(windowLeftIndex:windowRightIndex);
                    plot(windowSelA, defaultWvlWindow, defaultPwrWindow, 'b');
                    hold(windowSelA, 'on')
                    plot(windowSelA, wvlPeak, pwrPeak, 'r+');
                    hold(windowSelA, 'off')
                    movegui(windowSelF, 'center')
                    pause(1)
                    %get new peak window
                    newWindow = getrect(windowSelA);  % this the new peak window size
                    windowLeft = newWindow(1);
                    windowSize = newWindow(3);
                    windowRight = windowLeft + windowSize;
                    windowLeftIndex = find(self.wvl - windowLeft <= 0);
                    if windowLeftIndex
                        windowLeftIndex = windowLeftIndex(end);
                    else
                        windowLeftIndex = 1;
                    end
                    windowLeft = self.wvl(windowLeftIndex);
                    windowRightIndex = find(windowRight >= self.wvl);
                    windowRightIndex = windowRightIndex(end);
                    windowRight = self.wvl(windowRightIndex);
                    refineWindowSize = windowRight - windowLeft;
                    close(windowSelF);
 %               end
                %Update peak info
                peakInfo = struct(...
                    'peakWvl', self.wvl(peakInd), ...
                    'peakPwr', self.pwr(peakInd), ...
                    'wvls', self.wvl(windowLeftIndex:windowRightIndex), ...
                    'pwrs', self.pwr(windowLeftIndex:windowRightIndex));
                self.peaks{activePeak}.updatePeakInfo(peakInfo);
                % Re-fit the peak.
                self.peaks{activePeak}.fitPeak();
                % Add later.
            end
        end
        
        function refindPeak(self, activePeak, varargin)
            %refinds the peak in a peak window offsetted by varargin{1}
            %varargin{2} contains the window in which to look for
            refineWvl = self.peaks{activePeak}.peakWvl;
            if nargin >= 3
                refineWvl = varargin{1};
            end

            if refineWvl ~= self.peaks{activePeak}.peakWvl
                %reset rawPeakWvl ->starting point for fitting algoritm
                rawPeakWvl = refineWvl;
                
                %check whether new peak location is inside wvl range
                if rawPeakWvl <= min(self.wvl)
                    rawPeakWvl = min(self.wvl);
                end
                if rawPeakWvl>=max(self.wvl)
                    rawPeakWvl = max(self.wvl); 
                end
                
                if nargin>=4
                    window_size = varargin{2};
                else
                    %get peak window size (not fittet but window size)
                    window_size = self.peaks{activePeak}.raw.wvls(end)-...
                        self.peaks{activePeak}.raw.wvls(1);
                    %assuming new peak is in the center or near the center
                end


                wvlFilter = find((self.wvl-(rawPeakWvl-window_size/2) >= 0)...
                    &(self.wvl-(rawPeakWvl+window_size/2)<=0));
                 if self.DEBUG
                    msg=strcat('ScanClass re-find peak => old PeakWvl = ', num2str(self.peaks{activePeak}.peakWvl));
                    disp(msg);
                    msg=strcat('ScanClass re-find peak => rawPeakWvl = ', num2str(rawPeakWvl));
                    disp(msg);
                    msg=strcat('ScanClass re-find peak => minWvl = ', num2str(min(self.wvl)));
                    disp(msg);
                    msg=strcat('ScanClass re-find peak => maxWvl = ', num2str(max(self.wvl)));
                    disp(msg);
                    msg=strcat('ScanClass re-find peak => window_size = ', num2str(window_size));
                    disp(msg) 
                    msg=strcat('ScanClass re-find peak => wvlFilter size = ', num2str(length(wvlFilter)));
                    disp(msg); 
                    msg=strcat('ScanClass re-find peak => wvl size = ', num2str(length(self.wvl)));
                    disp(msg); 
                    msg=strcat('ScanClass re-find peak => pwr size = ', num2str(length(self.pwr)));
                    disp(msg); 
                end
                
                if isempty(wvlFilter)
                    errordlg('wvlFilter is empty', 're-find Peak');
                else
                    wvl_filtered = self.wvl(wvlFilter); 
                    pwr_filtered = self.pwr(wvlFilter); 
                end
                   
                % Find the peak power value within the limited range above
                if self.isPeak(activePeak)
                    [pwrPeak, ind] = max(pwr_filtered); % look for index of min y in range

                else
                    [pwrPeak, ind] = min(pwr_filtered); % look for index of min y in range
                end
    
                %if multiple peaks take the last one
                new_PeakWvl  = wvl_filtered(ind(end));
                new_PeakPwr = pwr_filtered(ind(end)); 

                %compute new window and check if inside wvl range. 
                
                windowLeft = new_PeakWvl - window_size/2;
                windowRight = rawPeakWvl + window_size/2;
                windowLeftIndex = find(self.wvl - windowLeft <= 0);
                if isempty(windowLeftIndex)
                    windowLeftIndex = 1;
                else
                    windowLeftIndex = windowLeftIndex(end);
                end
                windowRightIndex = find(self.wvl - windowRight <= 0);
                windowRightIndex = windowRightIndex(end);
                
                %update the peak; 
                peakInfo = struct(...
                    'peakWvl', new_PeakWvl, ...
                    'peakPwr', new_PeakPwr, ...
                    'wvls', self.wvl(windowLeftIndex:windowRightIndex), ...
                    'pwrs', self.pwr(windowLeftIndex:windowRightIndex));
                
                self.peaks{activePeak}.updatePeakInfo(peakInfo);
                %refit the peak. 
                self.peaks{activePeak}.fitPeak();
 
            else %peak is assumed to be at same position
                    self.peaks{activePeak}.fitPeak();
            end
        end
        
        function updateScanInfo(self, scanInfo)
            infoNames = fieldnames(scanInfo);
            for n = 1:length(infoNames)
                self.(infoNames{n}) = scanInfo.(infoNames{n});
            end
        end        
    end
end

