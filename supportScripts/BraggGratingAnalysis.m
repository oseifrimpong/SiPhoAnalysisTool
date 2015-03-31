%% Bragg Grating Analysis & Comparison
%%     -developed in: 04/05/2014
%% Vince Wu
function BraggGratingAnalysis(parentPath, testType, testTimeStamp, mode, file, checkChannel, exculdeChannels)
response = questdlg(...
    'Load previous data validation result?', ...
    'Bragg Grating Analysis', ...
    'Yes', 'No', 'Yes');
isValidated = 0;
if strcmpi(response, 'Yes')
    [fileName, filePath] = uigetfile('*.mat', 'Select a Validation Data', parentPath);
    if fileName ~= 0
        validationData = load([filePath, fileName]);
        keepScan = validationData.keepScan;
        isValidated = 1;
    else
        error('Invalid File Selection');
    end
else
   keepScan = []; 
end

% Analysis Information
deviceListStruct = dir(parentPath);
deviceListStruct = deviceListStruct(3:end);
devices = struct();

lengthAll = [];
periodAll = [];
corrAll = [];

deviceIndex = 0;
for d = 1:length(deviceListStruct)
    thisDevice = deviceListStruct(d).name;
    if ~isempty(strfind(thisDevice, mode)) && ~isempty(strfind(thisDevice, 'Bragg'))
        dataPath = (strcat(parentPath, thisDevice, '\', testType, '\', testTimeStamp, '\', file));
        if exist(dataPath, 'file')
            deviceIndex = deviceIndex + 1;
            testResult = load(dataPath);
            deviceComment = (testResult.deviceInfo.Comment);
            if ~isValidated
                numOfChannel = length(testResult.scanResults) - length(exculdeChannels);
                colors = {'g', 'b', 'c', 'm'};
                f = figure('Units', 'Normalized', 'Position', [.30 .10 .40 .80]);
                plotIndex = 0;
                for channel = 1:numOfChannel
                    if all(channel ~= exculdeChannels)
                        plotIndex = plotIndex + 1;
                        subplot(numOfChannel, 1, plotIndex)
                        plot(testResult.scanResults(channel).Data(:, 1), testResult.scanResults(channel).Data(:, 2), colors{mod(channel, length(colors)) + 1});
                        title(sprintf('Device: %s Comment: %s\n%s on %s Detector %d', strrep(thisDevice, '_', '-'), strrep(deviceComment, '_', '-'), testType, testTimeStamp, channel));
                        xlabel('Wavelength (nm)');
                        ylabel('Power (dB)');
                    end
                end
                response = questdlg(...
                    'Keep this scan?', ...
                    'Bragg Grating Analysis', ...
                    'keep', 'skip', 'keep');
                if strcmpi(response, 'keep')
                    keepScan(end + 1) = 1;
                else
                    keepScan(end + 1) = 0;
                end
                delete(f);
            end
            
            if keepScan(deviceIndex)
                deviceComment = strsplit(deviceComment, '-');
                lengthAll(end + 1) = str2double(strrep(deviceComment{2}, 'um', ''));
                periodAll(end + 1) = str2double(strrep(deviceComment{4}, 'nm', ''));
                corrAll(end + 1) = str2double(strrep(deviceComment{6}, 'nm', ''));
                
                devices.(thisDevice) = struct(...
                    'mode', mode, ...
                    'length', lengthAll(end), ...
                    'period', periodAll(end), ...
                    'corr', corrAll(end), ...
                    'wvlData', testResult.scanResults(checkChannel).Data(:, 1), ...
                    'pwrData', testResult.scanResults(checkChannel).Data(:, 2));
            end
        end
    end
end
if ~isValidated
    save(sprintf('%sBraggGratingAnalysis_Detector%d_validation.mat', parentPath, checkChannel), 'keepScan');
end

% Obtain Unique length, period and corrAll
deviceNames = fieldnames(devices);
lengthOpt = unique(lengthAll);
periodOpt = unique(periodAll);
corrOpt = unique(corrAll);

colors = {'r', 'g', 'b', 'c', 'm', 'k', 'y'};

%% Analysis #1: plot spectra for gratings with same length and period (different corrugation widths)
for l = 1:length(lengthOpt)
    for p = 1:length(periodOpt)
        thisLength = find(lengthAll == lengthOpt(l));
        thisPeriod = find(periodAll == periodOpt(p));
        
        thisDevicesSet = [];
        for ll = thisLength
            for pp = thisPeriod
                if ll == pp
                    thisDevicesSet(end+1) = ll;
                end
            end
        end
        
        figure('Units', 'Normalized', 'Position', [.10 .20 .80 .60]);
        legendS = {};
        hold on
        plotIndex = 0;
        for d = thisDevicesSet
            plotIndex = plotIndex + 1;
            thisCorr = devices.(deviceNames{d}).corr;
            legendS{end+1} = sprintf('Device: %s\nCorrugation = %.1fnm', strrep(deviceNames{d}, '_', '-'), thisCorr);
            plot(devices.(deviceNames{d}).wvlData, devices.(deviceNames{d}).pwrData, colors{mod(plotIndex, length(colors)) + 1});
        end
        title(sprintf('Length = %.1fum, Period = %.1fnm', lengthOpt(l), periodOpt(p)), 'FontSize', 12, 'FontWeight', 'bold');
        xlabel('Wavelength (nm)', 'FontSize', 11, 'FontWeight', 'bold');
        ylabel('Power (dB)', 'FontSize', 11, 'FontWeight', 'bold');
        legend(legendS, 'Location', 'BestOutside');
        hold off
    end
end

%% Analysis #2: plot spectra for gratings with same period and corrugation (different 'lengths)
for p = 1:length(periodOpt)
    for c = 1:length(corrOpt)
        thisPeriod = find(periodAll == periodOpt(p));
        thisCorr = find(corrAll == corrOpt(c));
        
        thisDevicesSet = [];
        for pp = thisPeriod
            for cc = thisCorr
                if pp == cc
                    thisDevicesSet(end+1) = pp;
                end
            end
        end
        
        figure('Units', 'Normalized', 'Position', [.10 .20 .80 .60]);
        legendS = {};
        hold on
        plotIndex = 0;
        for d = thisDevicesSet
            plotIndex = plotIndex + 1;
            thisLength = devices.(deviceNames{d}).length;
            legendS{end+1} = sprintf('Device: %s\nLength = %.1fum', strrep(deviceNames{d}, '_', '-'), thisLength);
            plot(devices.(deviceNames{d}).wvlData, devices.(deviceNames{d}).pwrData, colors{mod(plotIndex, length(colors)) + 1});
        end
        title(sprintf('Period = %.1fnm, Corrugation = %.1fnm', periodOpt(p), corrOpt(c)), 'FontSize', 12, 'FontWeight', 'bold');
        xlabel('Wavelength (nm)', 'FontSize', 11, 'FontWeight', 'bold');
        ylabel('Power (dB)', 'FontSize', 11, 'FontWeight', 'bold');
        legend(legendS, 'Location', 'BestOutside');
        hold off
    end
end
end
