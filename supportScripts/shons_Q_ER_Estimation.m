function [Q, ER, D, A, F] = shons_Q_ER_Estimation(filePath, includeChannels, fitting)
% 4/12/2014 Vince
% 4/12/2014 Shon fixed all of Vince's bugs (and actually got it to work correctly).
% 5/16/2014 shon added strsplit.m to dir and fixed some backwards compatability
% 5/17/2014 shon adapted for many devices
%% user input
chopOffLength = 1000; % number of samples to chop off the end

% partition the input filePath and get the data directory path
splitItems = strsplit(filePath,'\');
if length(splitItems) > 8 % assume \\pandora.bioeng.washington.edu\BioBenchData\...
    parsedInfo.rootPath = splitItems{end-8};
    parsedInfo.rootFolder = splitItems{end-7};
    parsedInfo.foundry = splitItems{end-6};
    parsedInfo.chip = splitItems{end-5};
    parsedInfo.die = splitItems{end-4};
    parsedInfo.device = splitItems{end-3}; % shon 5/16/2014
    parsedInfo.testType = splitItems{end-2};
    parsedInfo.testDate =splitItems{end-1};
    parsedInfo.fileName =splitItems{end};
    dirPath = strcat('\\',...
        parsedInfo.rootPath,'\',...
        parsedInfo.rootFolder,'\',...
        parsedInfo.foundry,'\',...
        parsedInfo.chip,'\',...
        parsedInfo.die,'\',...
        parsedInfo.device,'\',...
        parsedInfo.testType,'\',...
        parsedInfo.testDate);
else % assume Z:\...
    parsedInfo.rootPath = splitItems{end-7};
    parsedInfo.foundry = splitItems{end-6};
    parsedInfo.chip = splitItems{end-5};
    parsedInfo.die = splitItems{end-4};
    parsedInfo.device = splitItems{end-3}; % shon 5/16/2014
    parsedInfo.testType = splitItems{end-2};
    parsedInfo.testDate =splitItems{end-1};
    parsedInfo.fileName =splitItems{end};
    dirPath = strcat(...
        parsedInfo.rootPath,'\',...
        parsedInfo.foundry,'\',...
        parsedInfo.chip,'\',...
        parsedInfo.die,'\',...
        parsedInfo.device,'\',...
        parsedInfo.testType,'\',...
        parsedInfo.testDate);
end;

%% check for existing analysis files, if exist, skip
fn = strcat(dirPath,'\','*QandER.mat');
if exist(fn, 'file')
    msg = sprintf('Q and ER analysis already exist for this device. Do you want to re-run?\n');
    response = questdlg(msg,...
        'Re-run analysis',...
        'Yes', 'No', 'No');
    if strcmpi(response, 'no')
        % assign previous values and return
        % load results file and return D (deviceInfo struct), Q, ER, and A...
        return;
    end
end

%% load the .mat results file
testResult = load(filePath);
D = testResult.deviceInfo; % capture and return device info struct
numChannels = length(testResult.scanResults);
Q = zeros(1,numChannels);
QFit = zeros(1,numChannels);
ER = zeros(1,numChannels);
ERFit = zeros(1,numChannels);
A = zeros(1,numChannels);
F = zeros(1, numChannels);
response = cell(1, numChannels);

%% loop through each detector and prompt the user to select the peak
for thisChannel = 1:numChannels
    if any(includeChannels == thisChannel)
        % load wavelength and power data
        wvlData = testResult.scanResults(thisChannel).Data(:, 1);
        wvlData = wvlData(1:end-chopOffLength);
        pwrData = testResult.scanResults(thisChannel).Data(:, 2);
        pwrData = pwrData(1:end-chopOffLength);
        
        % plot scan and prompt to analyze
        figure('Units', 'Normalized', 'Position', [.20, .30, .60, .40]);
        ha_data = axes;
        plot(1:length(wvlData), pwrData, 'b'), grid on;
        title(ha_data, sprintf('Device=%s Detector=%d\nComment=%s',strrep(testResult.deviceInfo.Name, '_', '-'), thisChannel,strrep(testResult.deviceInfo.Comment, '_', '-')), 'FontSize', 12, 'FontWeight', 'bold');
        xlabel(ha_data,'Wavelength (nm)', 'FontSize', 11, 'FontWeight', 'bold');
        ylabel(ha_data,'Power (dB)', 'FontSize', 11, 'FontWeight', 'bold');
        
        msg = sprintf('Do you want to analyze this scan for device %s detector%d?\n',strrep(testResult.deviceInfo.Name, '_', '-'),thisChannel);
        response{thisChannel} = questdlg(msg,...
            'Selection',...
            'Yes', 'No', 'Quit', 'No');
        
        if strcmpi(response{thisChannel}, 'Quit')
            close all;
            error('User quit.');
        end
        
        if strcmpi(response{thisChannel}, 'Yes')
            A(thisChannel) = 1; % analyzed? 1=yes, 0=no
            peakType = questdlg(...
                'What kind of resonance?', ...
                'Q and ER estimation',...
                'Peak', 'Null', 'Peak');
            
            normalize = questdlg(...
                'Normalization Selection', ...
                'Normalize?',...
                'Yes', 'No', 'Yes');
            
            window = getrect(ha_data);
            windowMin = round(window(1));
            windowSize = round(window(3));
            windowMax = min(windowMin + windowSize, length(wvlData));
            wvlWindow = wvlData(windowMin:windowMax);

            if normalize
                val = max(pwrData(windowMin:windowMax));
                pwrWindow = pwrData(windowMin:windowMax) - val;
            else
                pwrWindow = pwrData(windowMin:windowMax);
            end
            % Plot the peak
            figure('Units', 'Normalized', 'Position', [.20 .30 .60 .40]);
            ha_window = axes;
            hold(ha_window, 'on')
            plot(ha_window, wvlWindow, pwrWindow, 'k', 'linewidth', 2.5);
            if fitting
                P = polyfit(wvlWindow, pwrWindow, 8);
                pwrWindowFit = polyval(P, wvlWindow);
                plot(ha_window, wvlWindow, pwrWindowFit, 'g');
            end
            F(thisChannel) = 1;
            hold(ha_window, 'off')
            title(ha_window, sprintf('Device=%s Detector=%d\nTestType=%s Date=%s\nComment=%s\n',strrep(testResult.deviceInfo.Name, '_', '-'),thisChannel,parsedInfo.testType,parsedInfo.testDate,strrep(testResult.deviceInfo.Comment, '_', '-')), 'FontSize', 12, 'FontWeight', 'bold');
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
                %                    fprintf('Detector%d => min power = %.1f at wavelength = %.1f\n', thisChannel, minPwr,wvlAtMinPwr);
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
                
                if fitting
                    % Fitting part
                    [minPwrFit, indexFit] = min(pwrWindowFit);
                    wvlAtMinPwrFit = wvlWindow(indexFit);
                    pwrLeft = pwrWindowFit(indexFit); % initial power val going left and up
                    pwrLeftIndex = indexFit; % initial index val going left and up
                    pwrRight = pwrWindowFit(indexFit); % initial power val going right and up
                    pwrRightIndex = indexFit; % initial index val going right and up
                    while (pwrLeft < baseline - 3) && pwrLeftIndex > 1 % 3dB down
                        % decrement index and check power val
                        pwrLeftIndex = pwrLeftIndex - 1;
                        pwrLeft = pwrWindowFit(pwrLeftIndex);
                    end
                    while (pwrRight < baseline - 3) && pwrRightIndex < length(pwrWindow) % 3dB down
                        % increment index and check power val
                        pwrRightIndex = pwrRightIndex + 1;
                        pwrRight = pwrWindowFit(pwrRightIndex);
                    end
                    min3dBWvlFit = wvlWindow(pwrLeftIndex); % in nm's
                    max3dBWvlFit = wvlWindow(pwrRightIndex); % in nm's
                    QFit(thisChannel) = wvlAtMinPwrFit /(max3dBWvlFit-min3dBWvlFit);
                    ERFit(thisChannel) = baseline - minPwrFit;
                end
            else % is a peak
                % look for the maxima in the window
                % assume power vals are in dB
                %        plot(pwrData(windowMin:windowMax))
                [maxPwr, index] = max(pwrWindow);
                wvlAtMaxPwr = wvlWindow(index); % in nm's
                % report
                %            fprintf('%s Detector%d: max power = %.1f at wavelength = %.1f\n', thisDevice, thisChannel, maxPwr, wvlAtMaxPwr);
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
                
                if fitting
                    % Fitting part
                    [maxPwrFit, indexFit] = max(pwrWindowFit);
                    wvlAtMinPwrFit = wvlWindow(indexFit);
                    pwrLeft = pwrWindowFit(indexFit); % initial power val going left and up
                    pwrLeftIndex = indexFit; % initial index val going left and up
                    pwrRight = pwrWindowFit(indexFit); % initial power val going right and up
                    pwrRightIndex = indexFit; % initial index val going right and up
                    while (pwrLeft > maxPwrFit - 3) && pwrLeftIndex > 1 % 3dB down
                        % decrement index and check power val
                        pwrLeftIndex = pwrLeftIndex - 1;
                        pwrLeft = pwrWindowFit(pwrLeftIndex);
                    end
                    while (pwrRight > maxPwrFit - 3) && pwrRightIndex < length(pwrWindow) % 3dB down
                        % increment index and check power val
                        pwrRightIndex = pwrRightIndex + 1;
                        pwrRight = pwrWindowFit(pwrRightIndex);
                    end
                    min3dBWvlFit = wvlWindow(pwrLeftIndex); % in nm's
                    max3dBWvlFit = wvlWindow(pwrRightIndex); % in nm's
                    QFit(thisChannel) = wvlAtMinPwrFit /(max3dBWvlFit-min3dBWvlFit);
                    ERFit(thisChannel) = maxPwrFit - baseline;
                end
            end
            
            % Plot the two 3dB lines
            yl = ylim(ha_window);
            hold(ha_window, 'on')
            plot(min3dBWvl*ones(1, 20), linspace(yl(1), yl(2), 20), 'b--');
            plot(max3dBWvl*ones(1, 20), linspace(yl(1), yl(2), 20), 'b--');
            if fitting
                plot(min3dBWvlFit*ones(1, 20), linspace(yl(1), yl(2), 20), 'g--');
                plot(max3dBWvlFit*ones(1, 20), linspace(yl(1), yl(2), 20), 'g--');
                title(ha_window, sprintf('Device=%s Detector=%d\ntestType=%s Date=%s\nComment=%s\nQ=%.1f ER=%.1fdB\nQ_{Fit}=%.1f ER_{Fit}=%.1fdB',strrep(testResult.deviceInfo.Name, '_', '-'), thisChannel, parsedInfo.testType, parsedInfo.testDate, strrep(testResult.deviceInfo.Comment, '_', '-'), Q(thisChannel), ER(thisChannel), QFit(thisChannel), ERFit(thisChannel)), 'FontSize', 12, 'FontWeight', 'bold');
            else
                title(ha_window, sprintf('Device=%s Detector=%d\ntestType=%s Date=%s\nComment=%s\nQ=%.1f ER=%.1fdB',strrep(testResult.deviceInfo.Name, '_', '-'), thisChannel, parsedInfo.testType, parsedInfo.testDate, strrep(testResult.deviceInfo.Comment, '_', '-'), Q(thisChannel), ER(thisChannel)), 'FontSize', 12, 'FontWeight', 'bold');
            end
            hold(ha_window, 'off')
            % report
            if fitting
                fprintf('%s\n  Detector%d => Q = %.1f; ER = %.1fdB\nQFit = %.1f; ERFit = %.1fdB\n',parsedInfo.device,thisChannel, Q(thisChannel), ER(thisChannel), QFit(thisChannel), ERFit(thisChannel));
            else
                fprintf('%s\n  Detector%d => Q = %.1f; ER = %.1fdB\n',parsedInfo.device,thisChannel, Q(thisChannel), ER(thisChannel));
            end
            % write files to directory
            % shon moved inside loop and added detector to fn 5/16/2014
            % save testResult.deviceInfo and plot to local directory
            QandER = struct(...
                'Q', Q, ...
                'ER', ER, ...
                'deviceInfo', testResult.deviceInfo);
            fn = strcat(dirPath, '\', 'Ch', num2str(thisChannel), 'QandER');
            save(fn, '-struct', 'QandER');
            saveas(ha_window, fn, 'fig');
            saveas(ha_window, fn, 'pdf');
        end
        close all;
    end
end
end