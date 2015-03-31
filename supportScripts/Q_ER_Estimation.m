function [Q, ER, deviceInfo] = Q_ER_Estimation(filePath)
close all
%% Q Estimation: developed in 04/12/2014
% Vince 04/12/2014
% 4/12/2014. Shon fixed all of Vince's bugs (and actually got it to work correctly).
% 5/16/2014. shon added strsplit.m to dir and fixed some backwards compatability
%% user input
chopOffLength = 1000; % number of samples to chop off the end
if isempty(filePath)
    error('No directory specified.');
    %filePath = '\\pandora.bioeng.washington.edu\BioBenchData\EB\435Q3R\A\BioRing_27_27\WetTest\2014.04.09@21.17';
end

splitItems = strsplit(filePath,'\');
deviceInfo.path = splitItems{3};
deviceInfo.foundry = splitItems{5};
deviceInfo.chip = splitItems{6};
deviceInfo.die = splitItems{7};
deviceInfo.device = splitItems{8}; % shon 5/16/2014
deviceInfo.testType = splitItems{9};
deviceInfo.testDate =splitItems{10};

% check for analysis files, if exist, skip
fn = strcat(filePath,'\','QandER.mat');
if exist(fn, 'file')
    msg = sprintf('Q and ER analysis already exist for this device. Do you want to re-run?\n');
    response = questdlg(msg,...
        'Re-run analysis',...
        'Yes', 'No', 'No');
    if strcmpi(response, 'no')
        % assign previous values and return
        QandER = load(fn);
        Q = QandER.Q;
        ER = QandER.ER;
        deviceInfo = QandER.deviceInfo;
        return;
    end
end

%% Get the wet test scan
% look for 'scan1.mat', if it doesn't exist, look for 'scan2.mat', if
% 'scan2.mat doesn't exist, error out
fn = strcat(filePath,'\','Scan1.mat');
if ~exist(fn, 'file')
    disp('Scan1.mat does not exist. Trying Scan2.mat');
    fn = strcat(filePath,'\','Scan2.mat');
    if ~exist(fn, 'file')
        error('Scan1.mat or Scan2.mat file does not exist. Exiting');
    else
        disp('Reading Scan2.mat');
    end
else
    disp('Reading Scan1.mat');
end

% Load the Data
scanData = load(fn);
% shon 5/16/2014
if ~(exist('scanData.deviceInfo.Name', 'var'))
    disp('Var scanData.deviceInfo.Name does not exist. Getting device name from directory path.');
    deviceInfo.deviceName = strrep(deviceInfo.device, '_', '-');
else
    deviceInfo.deviceName = strrep(scanData.deviceInfo.Name, '_', '-');
end

% shon 5/16/2014
if ~(exist('deviceInfo.deviceComment', 'var'))
    disp('Var scanData.deviceInfo.Name does not exist. Getting device name from directory path.');
    deviceInfo.deviceComment = 'no comment';
else
    deviceInfo.deviceComment = strrep(scanData.deviceInfo.Comment, '_', '-');
end;

% Determine number of channels in data set
[~, channels] = size(scanData.scanResults);

% initial outputs
Q = zeros(1,channels);
ER = zeros(1,channels);

response = cell(1, channels);
%% loop through each scan and prompt the user to select the peak
for thisChannel=1:channels
    % load wavelength and power data
    wvlData = scanData.scanResults(thisChannel).Data(:, 1);
    wvlData = wvlData(1:end-chopOffLength);
    pwrData = scanData.scanResults(thisChannel).Data(:, 2);
    pwrData = pwrData(1:end-chopOffLength);
    
    % plot scan and prompt to analyze
    % Plot the whole data
    figure('Units', 'Normalized', 'Position', [.20, .30, .60, .40]);
    ha_data = axes;
    plot(1:length(wvlData), pwrData, 'b'), grid on;
    %    title(sprintf('Device: %s Comment: %s\nDetector: %d: Scan %d/%d Data', deviceInfo.deviceName, deviceInfo.deviceComment, thisChannel, scanNum, numOfScan), 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('Device: %s Comment: %s\nDetector%d', deviceInfo.deviceName, deviceInfo.deviceComment, thisChannel), 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Wavelength (nm)', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Power (dB)', 'FontSize', 11, 'FontWeight', 'bold');
    
    msg = sprintf('Do you want to analyze this scan for device %s detector%d?\n',deviceInfo.deviceName,thisChannel);
    response{thisChannel} = questdlg(msg,...
        'Scanline selection',...
        'Yes', 'No', 'No');
    
    if strcmpi(response{thisChannel}, 'Yes')
        
        peakType = questdlg(...
            'What kind of resonance?', ...
            'Q and ER estimation',...
            'Peak', 'Null', 'Peak');
        
        %     if strcmpi(response, 'Null')
        %         pwrData = pwrData * (-1);
        %     end
        
        
        window = getrect(ha_data);
        windowMin = round(window(1));
        windowSize = round(window(3));
        windowMax = min(windowMin + windowSize, length(wvlData));
        wvlWindow = wvlData(windowMin:windowMax);
        pwrWindow = pwrData(windowMin:windowMax);
        
        % Plot the peak
        figure('Units', 'Normalized', 'Position', [.20 .30 .60 .40]);
        ha_window = axes;
        plot(ha_window, wvlWindow, pwrWindow, 'g');
        %    title(sprintf('Device: %s Comment: %s\nDetector: %d: Scan %d/%d Data', deviceInfo.deviceName, deviceInfo.deviceComment, thisChannel, scanNum, numOfScan), 'FontSize', 12, 'FontWeight', 'bold');
        title(ha_window, sprintf('Device: %s Comment: %s\nDetector%d', deviceInfo.deviceName, deviceInfo.deviceComment, thisChannel), 'FontSize', 12, 'FontWeight', 'bold');
        xlabel(ha_window, 'Wavelength (nm)', 'FontSize', 11, 'FontWeight', 'bold');
        ylabel(ha_window, 'Power (dB)', 'FontSize', 11, 'FontWeight', 'bold');
        
        % prompt for the baseline from which to calculate Q and ER
        % use window power and wavelength arrays
        [~,baseline] = ginput(1);
        % Plot the base line
        xl = xlim(ha_window);
        hold(ha_window, 'on')
        plot(linspace(xl(1), xl(2), 20), baseline*ones(1, 20), 'r--');
        hold(ha_window, 'off')
        
        if strcmpi(peakType, 'Null')
            % look for the minima in the window
            % assume power vals are in dB
            %        plot(pwrData(windowMin:windowMax))
            [minPwr, index] = min(pwrWindow);
            wvlAtMinPwr = wvlWindow(index); % in nm's
            % report
            fprintf('Detector%d => min power = %.1f at wavelength = %.1f\n', thisChannel, minPwr,wvlAtMinPwr);
            % from the min, walk up each side until you reach baseline - 3dB
            pwrLeft = pwrWindow(index); % initial power val going left and up
            pwrLeftIndex = index; % initial index val going left and up
            pwrRight = pwrWindow(index); % initial power val going right and up
            pwrRightIndex = index; % initial index val going right and up
            % start at the top and go left
            while (pwrLeft < baseline - 3) && pwrLeftIndex > 1 % 3dB down
                % decrement index and check power val
                pwrLeftIndex = pwrLeftIndex - 1;
                pwrLeft = pwrWindow(pwrLeftIndex);
            end
            % go right
            while (pwrRight < baseline - 3) && pwrRightIndex < length(pwrWindow) % 3dB down
                % increment index and check power val
                pwrRightIndex = pwrRightIndex + 1;
                pwrRight = pwrWindow(pwrRightIndex);
            end
            % find wavelengths at pwrFitLeftIndex and pwrFitRightIndex
            min3dBWvl = wvlWindow(pwrLeftIndex); % in nm's
            max3dBWvl = wvlWindow(pwrRightIndex); % in nm's
            Q(thisChannel) = wvlAtMinPwr /(max3dBWvl-min3dBWvl);
            
            % calculate extinction ratio
            ER(thisChannel) = baseline - minPwr;
            
            % write files to directory
            % shon moved inside loop and added detector to fn 5/16/2014
            if any(strcmpi(response, 'Yes'))
                % save deviceInfo and plot to local directory
                QandER = struct(...
                    'Q', Q, ...
                    'ER', ER, ...
                    'deviceInfo', deviceInfo);
%                fn = strcat(filePath, '\', 'Detector', num2str(thisChannel), '_QandER.mat');
                fn = strcat(filePath, '\', 'Detector', num2str(thisChannel), '_QandER');
                save(fn, '-struct', 'QandER');
                saveas(ha_window, fn, 'fig');
                saveas(ha_window, fn, 'pdf');
            end

        else % is a peak
            % look for the maxima in the window
            % assume power vals are in dB
            %        plot(pwrData(windowMin:windowMax))
            [maxPwr, index] = max(pwrWindow);
            wvlAtMaxPwr = wvlWindow(index); % in nm's
            % report
            fprintf('Detector%d => max power = %.1f at wavelength = %.1f\n', thisChannel, maxPwr, wvlAtMaxPwr);
            % from the min, walk up each side until you reach baseline - 3dB
            pwrLeft = pwrWindow(index); % initial power val going left and up
            pwrLeftIndex = index; % initial index val going left and up
            pwrRight = pwrWindow(index); % initial power val going right and up
            pwrRightIndex = index; % initial index val going right and up
            % start at the top and go left
            while (pwrLeft > maxPwr - 3) && pwrLeftIndex > 1 % 3dB down
                % decrement index and check power val
                pwrLeftIndex = pwrLeftIndex - 1;
                pwrLeft = pwrWindow(pwrLeftIndex);
            end
            % go right
            while (pwrRight > maxPwr - 3) && pwrRightIndex < length(pwrWindow) % 3dB down
                % increment index and check power val
                pwrRightIndex = pwrRightIndex + 1;
                pwrRight = pwrWindow(pwrRightIndex);
            end
            % find wavelengths at pwrFitLeftIndex and pwrFitRightIndex
            min3dBWvl = wvlWindow(pwrLeftIndex); % in nm's
            max3dBWvl = wvlWindow(pwrRightIndex); % in nm's
            Q(thisChannel) = wvlAtMaxPwr /(max3dBWvl-min3dBWvl);
            
            % calculate extinction ratio
            ER(thisChannel) = maxPwr - baseline;
        end
        % Plot the two 3dB lines
        yl = ylim(ha_window);
        hold(ha_window, 'on')
        plot(min3dBWvl*ones(1, 20), linspace(yl(1), yl(2), 20), 'b--');
        plot(max3dBWvl*ones(1, 20), linspace(yl(1), yl(2), 20), 'b--');
        title(ha_window, sprintf('Device: %s Comment: %s\nDetector: %d\nQ = %.1f ER = %.1fdB', deviceInfo.deviceName, deviceInfo.deviceComment, thisChannel, Q(thisChannel), ER(thisChannel)), 'FontSize', 12, 'FontWeight', 'bold');
        hold(ha_window, 'off')
        % report
        fprintf('Detector%d => Q = %.1f; ER = %.1fdB\n', thisChannel, Q(thisChannel), ER(thisChannel));

        % write files to directory
        % shon moved inside loop and added detector to fn 5/16/2014
        if any(strcmpi(response, 'Yes'))
            % save deviceInfo and plot to local directory
            QandER = struct(...
                'Q', Q, ...
                'ER', ER, ...
                'deviceInfo', deviceInfo);            
%            fn = strcat(filePath, '\', 'Detector', num2str(thisChannel), '_QandER.mat');
            fn = strcat(filePath, '\', 'Detector', num2str(thisChannel), '_QandER');
            save(fn, '-struct', 'QandER');
            saveas(ha_window, fn, 'fig');
            saveas(ha_window, fn, 'pdf');
        end

    end
end
%print directory link to console window - shon 5/16/2014
disp(filePath);
close all;
end