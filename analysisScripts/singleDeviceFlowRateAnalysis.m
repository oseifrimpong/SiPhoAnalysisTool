function obj = singleDeviceFlowRateAnalysis(obj)
% Vince Dec 2014

%% old style
% Recipe copied for reference
% %<well>,<time(min)>,<reagent>,<ri>,<velocity>,<temp>,<comment>
% 7,60,DIW,1,0,30,degassed
% 7,60,DIW,1,1,30,degassed
% 7,60,DIW,1,10,30,degassed
% 7,60,DIW,1,100,30,degassed

%% new style
% %<well>,<time(min)>,<reagent>,<ri>,<velocity>,<temp>,<comment>
% 7,55,DIW@1ToEquilibriate,1.33,1,30,equilibriate
% 7,55,DIW@0,1.33,0,30,DIW@0uL/min
% 7,55,DIW@1,1,1.33,30,DIW@1uL/min
% 7,55,DIW@10,1.33,10,30,DIW@10uL/min
% 7,55,DIW@100,1.33,100,30,DIW@100uL/min

wb = waitbar(0, 'Flow Rate Characterization Analysis');
movegui(wb, 'center');

results = [];
chop = 5;

% Get flow rate info
previousFlowRate = NaN;
previousReagent = '';
flowRateVals = [];
flowRateChangeIndex = [];
reagentName = {};
numOfFlowRateVals = 0;
for scanNumber = obj.firstScanNumber:obj.lastScanNumber
    if ~any(scanNumber == obj.appParams.tempActiveChannelExcludedScans)
        thisFlowRate = obj.dataset{obj.appParams.activeChannel, scanNumber}.params.FlowRate;
        thisReagent = obj.dataset{obj.appParams.activeChannel, scanNumber}.params.ReagentName;
        % within the same reagent grouping
        if (thisFlowRate ~= previousFlowRate || ~strcmpi(thisReagent, previousReagent))
            numOfFlowRateVals = numOfFlowRateVals + 1;
            flowRateVals(end + 1) = thisFlowRate;
            if strcmpi(thisReagent, 'DIW@0')
                flowRateVals(end) = 0;
            end
            flowRateChangeIndex(end + 1) = scanNumber;
            reagentName{end + 1} = thisReagent;
        end
        previousFlowRate = thisFlowRate;
        previousReagent = thisReagent;
    end
end
flowRateChangeIndex(end + 1) = obj.lastScanNumber;

waitbar(0.5, wb);

for chIndex = 1:length(obj.datasetParams.includedChannel)
    channel = obj.datasetParams.includedChannel(chIndex);
    results.channel(chIndex).channelNum = channel;
    for pIndex = 1:obj.datasetParams.numOfPeaks(channel)
        for frIndex = 1:numOfFlowRateVals
            flowRate = flowRateVals(frIndex);
            reagent = reagentName{frIndex};
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).flowRateVal = flowRate;
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).reagent = reagent;
            rawPeaks = [];
            fitPeaks = [];
            for scanNumber = flowRateChangeIndex(frIndex):flowRateChangeIndex(frIndex+1)-1
                if ~any(scanNumber == obj.appParams.tempActiveChannelExcludedScans)
                    rawPeaks = [rawPeaks obj.dataset{channel, scanNumber}.peaks{pIndex}.peakWvl];
                    fitPeaks = [fitPeaks obj.dataset{channel, scanNumber}.peaks{pIndex}.fitPeakWvl];
                end
            end
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rawPeaks = rawPeaks;
            meanVal = mean(rawPeaks(chop+1:end-chop));
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).meanRaw = meanVal;
            rawPeaksNorm = rawPeaks - meanVal;
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rawPeaksNorm = rawPeaksNorm;
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rmsRaw = rms(rawPeaksNorm);
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).stdRaw = std(rawPeaksNorm);
            
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).fitPeaks = fitPeaks;
            meanVal = mean(fitPeaks(chop+1:end-chop));
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).meanFit = meanVal;
            fitPeaksNorm = fitPeaks - meanVal;
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).fitPeaksNorm = fitPeaksNorm;
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rmsFit = rms(fitPeaksNorm);
            results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).stdFit = std(fitPeaksNorm);
        end
    end
end
waitbar(1, wb, 'Saving Analysis File')
analysisFilePath = [obj.path.datasetDir, 'FlowRateCharacterizationAnalysis.mat'];
save(analysisFilePath, '-struct', 'results')
waitbar(1, wb, 'Finish!')
delete(wb)

% Plotting
chFig = zeros(size(obj.datasetParams.includedChannel));
chAxes = zeros(size(obj.datasetParams.includedChannel));
for chIndex = 1:length(obj.datasetParams.includedChannel)
    chFig(chIndex) = figure;
    channel = obj.datasetParams.includedChannel(chIndex);
    rmsRaw = zeros(obj.datasetParams.numOfPeaks(channel), numOfFlowRateVals-1);
    stdRaw = zeros(obj.datasetParams.numOfPeaks(channel), numOfFlowRateVals-1);
    rmsFit = zeros(obj.datasetParams.numOfPeaks(channel), numOfFlowRateVals-1);
    stdFit = zeros(obj.datasetParams.numOfPeaks(channel), numOfFlowRateVals-1);
    for pIndex = 1:obj.datasetParams.numOfPeaks(channel)
        for frIndex = 2:numOfFlowRateVals
            rmsRaw(pIndex, frIndex-1) = results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rmsRaw;
            stdRaw(pIndex, frIndex-1) = results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).stdRaw;
            rmsFit(pIndex, frIndex-1) = results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rmsFit;
            stdFit(pIndex, frIndex-1) = results.channel(chIndex).peaks{pIndex}.flowRate(frIndex).stdFit;
        end
    end
    chAxes(chIndex) = axes;
    hold(chAxes(chIndex), 'on')
    peakColor = {'r', 'b', 'k', 'm'};
    peakShape = {'o', '^', 's', 'd'};
    legendS = cell(obj.datasetParams.numOfPeaks(channel), 1);
    for pIndex = 1:obj.datasetParams.numOfPeaks(channel)
        plot(chAxes(chIndex), flowRateVals(2:end), rmsRaw(pIndex, :)*1000, [peakColor{mod(pIndex, 4)+1}, peakShape{mod(pIndex, 4)+1}], 'MarkerSize', 8);
        legendS{pIndex} = sprintf('Peak#%d', pIndex);
    end
    legend(legendS);
    for pIndex = 1:obj.datasetParams.numOfPeaks(channel)
        errorbar(chAxes(chIndex), flowRateVals(2:end), rmsRaw(pIndex, :)*1000, stdRaw(pIndex, :)*1000/2, [peakColor{mod(pIndex, 4)+1}], 'LineStyle', 'none');
    end
    title(chAxes(chIndex), sprintf('Flow Rate Characterization - Channel %d', channel));
    xlabel('Flow Rate [uL/min]');
    ylabel('RMS [pm]');
end
end