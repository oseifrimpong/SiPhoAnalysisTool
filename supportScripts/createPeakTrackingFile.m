function [rawPeakTrackFile] = createPeakTrackingFile(analysisPath, firstNum, lastNum, fitType)
% analysisPath = path to dataset, must have '\' at the end
% check for '\' at end, append
if ~strcmpi (analysisPath(end), '\')
    analysisPath = strcat(analysisPath, '\');
end;

% make first filename
fn = strcat(analysisPath,'Scan',num2str(firstNum),'.mat');
% load first file to determine number of channels
load(fn); % yes, it will get reloaded later...
% what gets loaded =
% deviceInfo, params, scanResults, timeStamp
numOfChannels = length(scanResults);

% initialize variables
trackedVals = [];
trackedValsFit = [];
deltaFit = [];
Q=[]; % q

% loop through each channel individually
for channel = 1:numOfChannels
    % popup to determine peak or resonant null for this channel
    question = strcat('Tracking a peak for channel ', num2str(channel), '?');
    isPeak = questdlg(question, 'Peak or null selection', 'Yes', 'No', 'No');
    % to flip dataset so tracking and fitting is just one way
    if strcmpi(isPeak, 'Yes')
        peakDir = 1;
    else
        peakDir = -1;
    end
    
    % stay in while loop until no more files exist
    num=firstNum;
    while (exist(fn,'file')) && num <= lastNum
        load(fn);
        % big setup saves '0' for unused channels, so check for it
        % if no data (all zeros), skip
        % check for 0's in both wvl and pwr arrays
        if ~((scanResults(1,channel).Data(1,1)==0) && (scanResults(1,channel).Data(1,2)==0))
            
            % results are in struct w/ params and scanResults as fields
            % get ch1 and plot to select peaks to track
            %    xData = scanResults(1,1).Data(:,1);
            % chop off the last 1000 samples since something weired goes on w/ the
            % laser returning -200 for those points...not sure why...
            samples = length(scanResults(1,channel).Data(:,1));
            sampleLimit = samples-1000;
            xData = scanResults(1,channel).Data(1:sampleLimit,1);
            %        xRes = scanResults(1,channel).Data(2,1) - scanResults(1,channel).Data(1,1);
            yData = peakDir*scanResults(1,channel).Data(1:sampleLimit,2);
            xIndex = 1:length(xData); % need index for find func later on
            
            % hf1 is the raw data full scan
            if ~(exist('hf1','var'))
                hf1 = figure; % create figure handle
            else
                figure(hf1); % make figure window active
            end
            plot(xIndex, yData, 'b');            
            ha1=gca; % get active figure windows axes handles
            
            % remove the save/toss frame feature -- we need peakTracking.mat to match files that exist
            %         if ~strcmp(strResponse,'c') % continue to end
            %             strResponse = input('Keep? [y/n] = ','s'); % returns as string
            %         end
            %         if ~strcmp(strResponse,'n') % toss the frame
            
            % 1st scan to set tracking window and calc Q and iLoD
            if num==firstNum % first scan, get points for peak tracking window
                rect = getrect(ha1); % returns [xmin ymin width height]
                xMinInd = round(rect(1)); % get window lower bound
                windowSize=round(rect(3));
                xMaxInd = xMinInd+windowSize; % get window upper bound
            end
            
            % hf2 is the tracking window
            if ~(exist('hf2','var'))
                hf2 = figure; % figure handle
            else
                figure(hf2); % make figure window active
            end
            ha2=gca; % get active figure windows axes handles
            
            xWindowData = xData(xMinInd:xMaxInd);
            yWindowData = yData(xMinInd:xMaxInd); % to find max
            
            % plot tracking window
            figure(hf2); % make figure window active
            plot(ha2, xWindowData, yWindowData, 'b');
            
            % find maxima
            [maximaPwr,maximaIndex] = max(yWindowData);
            maximaWvl = xWindowData(maximaIndex);
            
            % pwr and wvl
            trackedVals = [trackedVals; maximaWvl, maximaPwr];
            
            % re-center tracking window for poly fit
            window = xMaxInd-xMinInd;
            offset = round(window/2)-maximaIndex; % offset from middle of window (-=right of middle, +=left of middle)
            xMinInd=xMinInd-offset; % new xMinInd
            xMaxInd=xMinInd+windowSize;
            
            xWindowData = xData(xMinInd:xMaxInd);
            yWindowData = yData(xMinInd:xMaxInd); % to find max
            
            hold on;
            % fitting
            if strcmp(fitType, 'lorentz')
                % loretz fit
                [maxPwr, P2i] = max(yWindowData);
                P2i = xWindowData(P2i);
                Ci = mean([yWindowData(1:round(P2i/2)); yWindowData(round(P2i*3/2):end)]);
                P1i = maxPwr + 3 - Ci;
                P3i = 1;
                Pi = [P1i, P2i, P3i, Ci];
                [y, param, resnorm, delta] = lorentzfit(xWindowData,yWindowData, Pi, [], '3c');
                param(2)
                Pi - param
                %         resnorm
            elseif strcmp(fitType, 'poly')
                % poly fit
                poly_degree = 3;
                [p, S] = polyfit(xWindowData, yWindowData, poly_degree);
                [y,delta] = polyval(p, xWindowData, S);
            else
                y = yWindowData;
                delta = 0;
            end
            % delta
            deltaFit = [deltaFit, delta];
            
            % find maxima for fit
            [maximaPwrFit, maximaIndexFit] = max(y);  %% jtk changed to max(-y)
            maximaWvlFit = xWindowData(maximaIndexFit);
            % trackedValsFit = [trackedValsFit; maximaWvlFit, maximaPwrFit];
            
            % plot on top of original
            plot(ha2, xWindowData, y, 'r');
            legend('Original', 'Fit');
            % calculate Q = full width at half max
            pwrValLeft = maximaWvlFit;
            pwrValLeftIndex = maximaIndexFit;
            pwrValRight = maximaWvlFit;
            pwrValRightIndex = maximaIndexFit;
            % start at the top and go left
            while (pwrValLeft > maximaPwrFit-3) && pwrValLeftIndex > 1% 3dB down
                % decrement index and check power val
                pwrValLeftIndex = pwrValLeftIndex-1;
                pwrValLeft = y(pwrValLeftIndex);
            end
            % go right
            while (pwrValRight > maximaPwrFit-3) && pwrValRightIndex < length(pwrValRightIndex)% 3dB down
                % increment index and check power val
                pwrValRightIndex = pwrValRightIndex+1;
                pwrValRight = y(pwrValRightIndex);
            end
            % find wavelengths at pwrValLeftIndex and pwrValRightIndex
            min3dBWvl = xData(xMinInd+pwrValLeftIndex);
            max3dBWvl = xData(xMinInd+pwrValRightIndex);
            Q = [Q, 1.550/(max3dBWvl-min3dBWvl)];
            hold off;

            % save tracked peaks for this channel
            PeakLocations{channel}{num} = maximaWvlFit;
            PeakLocationsN{channel}{num} = 0;
        else
            % no data for this channel
            PeakLocations{channel}{num} = 0;
            PeakLocationsN{channel}{num} = 0;
        end
        % create the next filename
        disp(num2str(num))
        num = num + 1;
        fn = strcat(analysisPath, 'Scan',num2str(num),'.mat');
    end % while loop
    
    saveFn = strcat(analysisPath, 'PeakTrackingShon.mat');
    save(saveFn, 'PeakLocations', 'PeakLocationsN');
end