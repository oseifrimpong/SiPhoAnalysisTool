% This function is used to calculate device sensitivity in Salt-Step test
% Vince Wu - Feb 11 2015
function obj = SaltStepAnalysis(obj)
numOfReagents = length(obj.reagentChangeIndex);
ReagentNames = cell(1, numOfReagents);
RI = zeros(1, numOfReagents);
% RI and Reagent Names will be the same in all channel: choose channel 1
for r = 1:numOfReagents
    ReagentNames{r} = obj.dataset{1, obj.reagentChangeIndex(r)}.params.ReagentName;
    RI(r) = obj.dataset{1, obj.reagentChangeIndex(r)}.params.ReagentRI;
end

includeRICheck = ones(1, numOfReagents);
for r = 1:numOfReagents
    if strcmp(ReagentNames{r}, 'DIW') || strcmp(ReagentNames{r}, '2M NaCl') || strcmp(ReagentNames(r), '1M NaCl') || strcmp(ReagentNames(r), '500mM NaCl')
    %if strcmp(ReagentNames{r}, 'DIW') || strcmp(ReagentNames{r}, '2M NaCl') || strcmp(ReagentNames(r), '1M NaCl')
    %if strcmp(ReagentNames{r}, 'DIW') || strcmp(ReagentNames{r}, '2M NaCl')
    includeRICheck(r) = 0;
    end
end

includeRI = RI(includeRICheck~=0);
includeReagentNames = ReagentNames(includeRICheck~=0);
includeReagentChangeIndex = obj.reagentChangeIndex(includeRICheck~=0);
appendIndex = find(includeReagentChangeIndex(end) == obj.reagentChangeIndex);
if  appendIndex < numOfReagents
    includeReagentChangeIndex(end + 1) = obj.reagentChangeIndex(appendIndex + 1);
else
    includeReagentChangeIndex(end + 1) = obj.lastScanNumber;
end

% Analysis & Plotting
for chIndex = 1:length(obj.datasetParams.includedChannel)
    channel = obj.datasetParams.includedChannel(chIndex);
    for pIndex = 1:obj.datasetParams.numOfPeaks(channel)
        % Arrange Data
        rawShiftArray = cell(length(includeRI), 1);
        rawMeanShiftArray = zeros(1, length(includeRI));
        rawErrShiftArray = zeros(1, length(includeRI));
        fitShiftArray = cell(length(includeRI), 1);
        fitMeanShiftArray = zeros(1, length(includeRI));
        fitErrShiftArray = zeros(1, length(includeRI));
        
        for riIndex = 1:length(includeRI)
            startScan = includeReagentChangeIndex(riIndex);
            stopScan = includeReagentChangeIndex(riIndex + 1) - 1;
            for scanNumber = startScan:stopScan
                if ~obj.dataset{channel, scanNumber}.excludeScan
            		rawShiftArray{riIndex} = [rawShiftArray{riIndex}, obj.dataset{channel, scanNumber}.peaks{pIndex}.peakWvl];
                    fitShiftArray{riIndex} = [fitShiftArray{riIndex}, obj.dataset{channel, scanNumber}.peaks{pIndex}.fitPeakWvl];
                end
            end
            rawMeanShiftArray(riIndex) = mean(rawShiftArray{riIndex});
            rawErrShiftArray(riIndex) = std(rawShiftArray{riIndex});
            fitMeanShiftArray(riIndex) = mean(fitShiftArray{riIndex});
            fitErrShiftArray(riIndex) = std(fitShiftArray{riIndex});
        end
        % Normalize Data
        rawMeanShiftArray = rawMeanShiftArray - rawMeanShiftArray(1);
        fitMeanShiftArray = fitMeanShiftArray - fitMeanShiftArray(1);
        % Estimate Sensitivity
        % Raw Data
        rawLineParam = polyfit(includeRI, rawMeanShiftArray, 1);
        rawSensitivity = rawLineParam(1); % Convert pm/RI to nm/RI
        rawS = sprintf('S = %dnm/RIU', round(rawSensitivity));
        rawLine = polyval(rawLineParam, includeRI);
        % Fit Data
        fitLineParam = polyfit(includeRI, fitMeanShiftArray, 1);
        fitSensitivity = fitLineParam(1); % Convert pm/RI to nm/RI
        fitS = sprintf('S = %dnm/RIU', round(fitSensitivity));
        fitLine = polyval(fitLineParam, includeRI);
        
        % Plotting - Raw Data
        sensitivityRawF = figure('Units', 'Normalized', 'Position', [.15 .15 .70 .70]);
        sensitivityRawH = axes('Parent', sensitivityRawF);
        hold(sensitivityRawH, 'on')
        plot(sensitivityRawH, includeRI, rawMeanShiftArray, 'go', 'MarkerSize', 8);
        errorbar(sensitivityRawH, includeRI, rawMeanShiftArray, rawErrShiftArray, 'g', 'LineStyle', 'none')
        plot(sensitivityRawH, includeRI, rawLine, 'm-', 'LineWidth', 2.1);
        text(includeRI(end), rawMeanShiftArray(end), rawS, 'FontSize', 11, 'FontWeight', 'bold', 'EdgeColor', 'b');
        title(sensitivityRawH, sprintf('Raw Data Analysis: Sensitivity \nChannel %d Peak %d', channel, pIndex), 'FontSize', 10, 'FontWeight', 'bold');
        xlabel(sensitivityRawH, 'Refractive Index', 'FontSize', 10, 'FontWeight', 'bold');
        ylabel(sensitivityRawH, 'Wavelength Shift [nm]', 'FontSize', 10, 'FontWeight', 'bold');
        grid on
        hold(sensitivityRawH, 'off')
        
        % Plotting - Fit Data
        sensitivityFitF = figure('Units', 'Normalized', 'Position', [.15 .15 .70 .70]);
        sensitivityFitH = axes('Parent', sensitivityFitF);
        hold(sensitivityFitH, 'on')
        plot(sensitivityFitH, includeRI, fitMeanShiftArray, 'bo', 'MarkerSize', 8);
        errorbar(sensitivityFitH, includeRI, fitMeanShiftArray, fitErrShiftArray, 'b', 'LineStyle', 'none')
        plot(sensitivityFitH, includeRI, fitLine, 'r-', 'LineWidth', 2.1);
        text(includeRI(end), fitMeanShiftArray(end), fitS, 'FontSize', 11, 'FontWeight', 'bold', 'EdgeColor', 'b');
        title(sensitivityFitH, sprintf('Fitted Data Analysis: Sensitivity \nChannel %d Peak %d', channel, pIndex), 'FontSize', 10, 'FontWeight', 'bold');
        xlabel(sensitivityFitH, 'Refractive Index', 'FontSize', 10, 'FontWeight', 'bold');
        ylabel(sensitivityFitH, 'Wavelength Shift [nm]', 'FontSize', 10, 'FontWeight', 'bold');
        grid on
        hold(sensitivityFitH, 'off')
    end
end

end