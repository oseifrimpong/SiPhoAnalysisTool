%% Test Result Reporting
%%     -developed in: 04/05/2014
%% Vince Wu

function TestResultReporting(parentPath, testType, testTimeStamp, file, exculdeChannels)
    deviceListStruct = dir(parentPath);
    deviceListStruct = deviceListStruct(3:end);
    %%
    for d = 1:length(deviceListStruct)
        thisDevice = deviceListStruct(d).name;
        dataPath = (strcat(parentPath, thisDevice, '\', testType, '\', testTimeStamp, '\', file));
        if exist(dataPath, 'file')
            testResult = load(dataPath);
            numOfChannel = length(testResult.scanResults) - length(exculdeChannels);
            deviceComment = testResult.deviceInfo.Comment;
            colors = {'g', 'b', 'c', 'm'};
            figure('Units', 'Normalized', 'Position', [.30 .10 .40 .80]);
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
        end
    end
end