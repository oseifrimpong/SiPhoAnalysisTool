%% Propagation Loss Analysis
%%     -developed in 04/05/2014

% Analysis of propagation Loss
function PropagationLossAnalysis(parentPath, LossDeviceKeyWord, mode, testType, testTimeStamp, file, peakWindow)
deviceListStruct = dir(parentPath);
disp('executing propagation loss analysis');
deviceListStruct = deviceListStruct(3:end);
%%
legendpeakWindowStr = {};
legendpeakWindowFitStr = {};
deviceLength = [];
pwrData = [];
wvlpeakWindow = [];
pwrpeakWindow = [];
pwrpeakWindowMean = [];
pwrpeakWindowFit = [];
pwrpeakWindowFitMax = [];
plotC = {'k', 'r', 'b', 'c', 'm', 'y'};
plotIndex= 0;
for d = 1:length(deviceListStruct)
    thisDevice = deviceListStruct(d).name;
    if strfind(thisDevice, LossDeviceKeyWord) 
        for fl = 1:length(file)
            dataPath = (strcat(parentPath, thisDevice, '\', testType, '\', testTimeStamp, '\', file{fl}));
            if exist(dataPath, 'file')
                break
            end
        end
        % Add this to specify params other than length -------------------
        pass = true;
%         if exist(dataPath, 'file')
%             testResultTemp = load(dataPath);
%             deviceCommentTemp = testResultTemp.deviceInfo.Comment;
%             deviceCommentTemp = strrep(deviceCommentTemp, '_', '-');
%             deviceCommentTemp = strsplit(deviceCommentTemp, '-');
%             deviceParam = str2double(strrep(deviceCommentTemp{2}, 'mm', ''));
%             % wg_width = [160,180,200, 225,250,275,300,400,500]
%             if deviceParam == 50
%                 pass = false;
%             end
%         end
        % ----------------------------------------------------------------
        if exist(dataPath, 'file') && pass
            testResult = load(dataPath);
            thisDevice = strrep(thisDevice, '_', '-');
            deviceComment = testResult.deviceInfo.Comment;
            deviceComment = strrep(deviceComment, '_', '-');
            numOfChannel = length(testResult.scanResults);
            colors = {'g', 'b', 'c', 'm'};
            f = figure('Units', 'Normalized', 'Position', [.30 .10 .40 .80]);
            for channel = 1:numOfChannel
                subplot(numOfChannel, 1, channel)
                plot(testResult.scanResults(channel).Data(:, 1), testResult.scanResults(channel).Data(:, 2), colors{mod(channel, length(colors)) + 1});
                title(sprintf('Device: %s Comment: %s\n%s on %s Detector %d', thisDevice, strrep(deviceComment, '_', '-'), testType, testTimeStamp, channel));
                xlabel('Wavelength (nm)');
                ylabel('Power (dB)');
            end
            response = questdlg(...
                'Which channel should be used?', ...
                'Propagation Loss Analysis', ...
                '1', '2', 'skip', '1');
            delete(f);
            
            if ~strcmpi(response, 'skip')
                plotIndex = plotIndex + 1;
                
                channel = str2double(response);
                deviceComment
                deviceComment = splitstring(deviceComment, '-');
                deviceLengthStr = deviceComment{2};
                deviceLength(end + 1) = str2double(strrep(deviceLengthStr, 'mm', ''));
                
                wvlData = testResult.scanResults(channel).Data(:, 1)';
                pwrData(end + 1, :) = testResult.scanResults(channel).Data(:, 2)';
                
                pwrpeakWindowTemp = pwrData(end, :);
                if ~exist('peakWindowIndex', 'var')
                    wvlpeakWindowLeft = find(wvlData <= peakWindow(1));
                    wvlpeakWindowRight = find(wvlData <= peakWindow(2));
                    peakWindowIndex = wvlpeakWindowLeft(end):wvlpeakWindowRight(end);
                    wvlpeakWindow = wvlData(peakWindowIndex);
                    pwrpeakWindow = pwrpeakWindowTemp(peakWindowIndex);
                    pwrpeakWindowMean = mean(pwrpeakWindow(end, :));
                    P = polyfit(wvlpeakWindow, pwrpeakWindow(end, :), 4);
                    pwrpeakWindowFit = polyval(P, wvlpeakWindow);
                    pwrpeakWindowFitMax = max(pwrpeakWindowFit);
                else
                    pwrpeakWindow(end + 1, :) = pwrpeakWindowTemp(peakWindowIndex);
                    pwrpeakWindowMean(end + 1) = mean(pwrpeakWindow(end, :));
                    P = polyfit(wvlpeakWindow, pwrpeakWindow(end, :), 3);
                    pwrpeakWindowFit(end + 1, :) = polyval(P, wvlpeakWindow);
                    pwrpeakWindowFitMax(end + 1) = max(pwrpeakWindowFit(end, :));
                end
                
                legendpeakWindowStr{end + 1} = thisDevice;
                legendpeakWindowStr{end + 1} = sprintf('%s Mean Power --> %.1fdB', deviceLengthStr, pwrpeakWindowMean(end));
                legendpeakWindowFitStr{end + 1} = thisDevice;
                legendpeakWindowFitStr{end + 1} = sprintf('%s Fitting Max Power --> %.1fdB', deviceLengthStr, pwrpeakWindowFitMax(end));
            end
        end
    end
end
% Process Data only when there are more than one valid data
if length(pwrpeakWindowMean) >= 2
    [deviceLength, I] = sort(deviceLength);
    pwrData = pwrData(I, :);
    pwrpeakWindow = pwrpeakWindow(I, :);
    pwrpeakWindowMean = pwrpeakWindowMean(I);
    pwrpeakWindowFit = pwrpeakWindowFit(I, :);
    pwrpeakWindowFitMax = pwrpeakWindowFitMax(I);
    numOfDevice = length(deviceLength);
    IforLegend = zeros(1, 2*numOfDevice);
    IforLegend(2:2:2*numOfDevice) = 2*I;
    IforLegend(1:2:end) = 2*I-1;
    legendpeakWindowStr = legendpeakWindowStr(IforLegend);
    legendpeakWindowFitStr = legendpeakWindowFitStr(IforLegend);
    
    %%
    % Peak Window
    propagationLosspeakWindow = figure('Units', 'Normalized', 'Position', [.05 .15 .90 .70]);
    propagationLosspeakWindowA = subplot(2, 2, 1);
    hold(propagationLosspeakWindowA, 'on');
    title(sprintf('%s Propagation Loss Peak Spectrum', mode), 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Length (mm)', 'FontSize', 10);
    ylabel('Power (dB)', 'FontSize', 10);
    grid on
    for m = 1:length(pwrpeakWindowMean)
        plot(propagationLosspeakWindowA, wvlpeakWindow, pwrpeakWindow(m, :), plotC{mod(m, length(plotC))+1});
        plot(propagationLosspeakWindowA, wvlpeakWindow, pwrpeakWindowMean(m)*ones(size(wvlpeakWindow)), [plotC{mod(m, length(plotC))+1}, '--']);
    end
    legendH = legend(propagationLosspeakWindowA, legendpeakWindowStr, 'Location', 'NorthEastOutside');
    set(legendH, 'FontSize', 6);
    hold(propagationLosspeakWindowA, 'off');
    propagationLosspeakWindowLineA = subplot(2, 2, 3);
    hold(propagationLosspeakWindowLineA, 'on');
    title(sprintf('%s Propagation Loss peakWindow Spectrum', mode), 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Length (mm)', 'FontSize', 10);
    ylabel('Power (dB)', 'FontSize', 10);
    grid on
    fitP = polyfit(deviceLength, pwrpeakWindowMean, 1);
    pwrpeakWindowMeanLine = polyval(fitP, deviceLength);
    plot(propagationLosspeakWindowLineA, deviceLength, pwrpeakWindowMean, 'bx', 'MarkerSize', 12);
    plot(propagationLosspeakWindowLineA, deviceLength, pwrpeakWindowMeanLine, 'r--');
    text(deviceLength(end), pwrpeakWindowMeanLine(end), sprintf('Loss = %.1fdB/cm', fitP(1)*10), 'FontSize', 11, 'FontWeight', 'bold', 'EdgeColor', 'b');
    hold(propagationLosspeakWindowLineA, 'off');
    
    % Peak Window Fitting
    % propagationLosspeakWindowFit = figure('Units', 'Normalized', 'Position', [.10 .20 .80 .60]);
    propagationLosspeakWindowFitA = subplot(2, 2, 2);
    hold(propagationLosspeakWindowFitA, 'on');
    title(sprintf('%s Propagation Loss Peak Spectrum (Fitting)', mode), 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Length (mm)', 'FontSize', 10);
    ylabel('Power (dB)', 'FontSize', 10);
    grid on
    for m = 1:length(pwrpeakWindowFitMax)
        plot(propagationLosspeakWindowFitA, wvlpeakWindow, pwrpeakWindowFit(m, :), plotC{mod(m, length(plotC))+1});
        plot(propagationLosspeakWindowFitA, wvlpeakWindow, pwrpeakWindowFitMax(m)*ones(size(wvlpeakWindow)), [plotC{mod(m, length(plotC))+1}, '--']);
    end
    legendH = legend(propagationLosspeakWindowFitA, legendpeakWindowFitStr, 'Location', 'NorthEastOutside');
    set(legendH, 'FontSize', 6);
    hold(propagationLosspeakWindowFitA, 'off');
    propagationLosspeakWindowFitLineA = subplot(2, 2, 4);
    hold(propagationLosspeakWindowFitLineA, 'on');
    title(sprintf('%s Propagation Loss peakWindow Spectrum (Fitting)', mode), 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Length (mm)', 'FontSize', 10);
    ylabel('Power (dB)', 'FontSize', 10);
    grid on
    fitP = polyfit(deviceLength, pwrpeakWindowFitMax, 1);
    pwrpeakWindowFitMaxLine = polyval(fitP, deviceLength);
    plot(propagationLosspeakWindowFitLineA, deviceLength, pwrpeakWindowFitMax, 'bx', 'MarkerSize', 12);
    plot(propagationLosspeakWindowFitLineA, deviceLength, pwrpeakWindowFitMaxLine, 'r--');
    text(deviceLength(end), pwrpeakWindowFitMaxLine(end), sprintf('Loss = %.1fdB/cm', fitP(1)*10), 'FontSize', 11, 'FontWeight', 'bold', 'EdgeColor', 'b');
    hold(propagationLosspeakWindowFitLineA, 'off');
    
    % Save plotting
    set(propagationLosspeakWindow, 'PaperOrientation', 'portrait');
    destinationFile = sprintf('%sPropagationLoassAnalysis_%s_%s_%s', parentPath, mode, LossDeviceKeyWord, testTimeStamp);
    saveas(propagationLosspeakWindow, [destinationFile, '.fig']);
    printPDF(propagationLosspeakWindow, [destinationFile, '.pdf']);
end
end