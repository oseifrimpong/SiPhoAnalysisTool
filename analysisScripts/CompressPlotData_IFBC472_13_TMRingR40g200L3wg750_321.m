% This function is used to analyze the laser jitter in the current active
% dataset - ShonS - July 2015
function obj = CompressPlotData_IFBC472_13_TMRingR40g200L3wg750_321(obj)
wb = waitbar(0, 'CompressPlotData_IFBC472_13_TMRingR40g200L3wg750_321');
movegui(wb, 'center');

% load peak tracking plot window data
fileName = '_temp_peakTrackingWindowDataExport.mat';
%[obj.path.datasetDir, fileName]
data = load([obj.path.datasetDir, fileName]);
%[x, yActiveCh, yTemperature, yRefCh, reagents, refChStr, activeChStr, xLabelName] = load([obj.path.datasetDir, fileName]);
% this is what gets loaded...as of 2 April 2016
% 'x'
% 'yActiveCh'
% 'yTemperature'
% 'yRefCh'
% 'reagents'
% 'refChStr'
% 'activeChStr'
% 'xLabelName'

thisReagent = data.reagents{1}; % set first reagent
% set first entry
reagentChangeIndex(1) = 1;
reagentName{1} = data.reagents{1};
index = 2;

% loop through on each reagent to find changes
for ii = 2:length(data.x)
    if ~strcmpi(thisReagent, data.reagents{ii})
        reagentChangeIndex(index) = ii;
        reagentName{index} = data.reagents{ii};
        % this group size
%        group = reagentChangeIndex(index)-reagentChangeIndex(index-1)
        index = index + 1;
    end
    thisReagent = data.reagents{ii};
end

% average all datapoints at each step
for jj = 2:length(reagentChangeIndex)
    avgs(jj-1) = mean(data.yActiveCh(reagentChangeIndex(jj-1):reagentChangeIndex(jj)));
    stdev(jj-1) = std(data.yActiveCh(reagentChangeIndex(jj-1):reagentChangeIndex(jj)));
end    

h = figure;
ax = gca;

hold(ax, 'on');

steps = linspace(1,length(reagentChangeIndex)-1,length(reagentChangeIndex)-1);
plot(ax,steps,avgs, 'LineStyle', 'none', 'Marker', '+');
errorbar(ax, steps,avgs,stdev, 'LineStyle', 'none', 'Color', 'b');

% plot fit
p = polyfit(steps, avgs, 2);
v = polyval(p, steps);
plot(ax,steps,v, 'LineStyle', '--', 'Color', 'r');

% plot dashed lines
yLimit = get(ax, 'ylim');
%plot(ax, self.appParams.xData(rcIndex)*ones(10, 1), linspace(yLimit(1), yLimit(2), 10), 'k--');

offset = 1.5;
for kk = 1:length(reagentChangeIndex)-1
    text(kk, avgs(kk)+offset-2*offset*(mod(kk,2)), ...
    sprintf(strrep(reagentName{kk}, ' ', '\n')), ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'normal', 'Color', [0 0 0]);
end

set(ax, 'XLim', [-1,kk+2]); % ensure text shows
set(ax, 'ylim', [yLimit(1) yLimit(2)]);

xlabel('Step Number');
ylabel('Wavelength Shift (nm)');
title('EV Field Characterization')
legend();

% results = [];
% outputFormat = {'Channel', 'Peak', 'Mean (raw)', 'raw RMS (pm)', 'raw STD (pm)', 'Mean (fit)', 'fit RMS (pm)', 'fit STD (pm)', 'Improvement %'};
% outputArray = outputFormat;
% % Get Laser Setting
% results.laserSetting = [];
% % Get Data
% % assume laser jitter is on ch4
% %for chIndex = 1:length(obj.datasetParams.includedChannel)
% for chIndex = 3:3
%     waitbar((chIndex-1)/length(obj.datasetParams.includedChannel), wb);
%     channel = obj.datasetParams.includedChannel(chIndex);
%     results.channel(chIndex).channelNum = channel;
%     for pIndex = 1:obj.datasetParams.numOfPeaks(channel)
%         rawPeaks = [];
%         fitPeaks = [];
%         for scanNumber = obj.firstScanNumber:obj.lastScanNumber
%             if ~any(scanNumber == obj.appParams.tempActiveChannelExcludedScans)
%                 rawPeaks = [rawPeaks, obj.dataset{channel, scanNumber}.peaks{pIndex}.peakWvl];
%                 fitPeaks = [fitPeaks, obj.dataset{channel, scanNumber}.peaks{pIndex}.fitPeakWvl];
%             end
%         end
%         results.channel(chIndex).peaks{pIndex}.rawPeaks = rawPeaks;
%         rawMean = mean(rawPeaks);
%         results.channel(chIndex).peaks{pIndex}.meanRaw = rawMean;
%         rawPeaksNorm = (rawPeaks - rawMean)*1000; %in pm
%         results.channel(chIndex).peaks{pIndex}.rawPeaksNorm = rawPeaksNorm;
%         results.channel(chIndex).peaks{pIndex}.rmsRaw = rms(rawPeaksNorm);
%         results.channel(chIndex).peaks{pIndex}.stdRaw = std(rawPeaksNorm);
%         
%         results.channel(chIndex).peaks{pIndex}.fitPeaks = fitPeaks;
%         fitMean = mean(fitPeaks);
%         results.channel(chIndex).peaks{pIndex}.meanFit = fitMean;
%         fitPeaksNorm = (fitPeaks - fitMean)*1000; % in pm
%         results.channel(chIndex).peaks{pIndex}.fitPeaksNorm = fitPeaksNorm;
%         results.channel(chIndex).peaks{pIndex}.rmsFit = rms(fitPeaksNorm);
%         results.channel(chIndex).peaks{pIndex}.stdFit = std(fitPeaksNorm);
%         
%         results.channel(chIndex).peaks{pIndex}.improvement = (results.channel(chIndex).peaks{pIndex}.rmsFit - results.channel(chIndex).peaks{pIndex}.rmsRaw)*100/results.channel(chIndex).peaks{pIndex}.rmsRaw;
%         
%         outputArray{end + 1, 1} = channel;
%         outputArray{end, 2} = pIndex;
%         outputArray{end, 3} = rawMean;
%         outputArray{end, 4} = round(results.channel(chIndex).peaks{pIndex}.rmsRaw*1000)/1000;
%         outputArray{end, 5} = round(results.channel(chIndex).peaks{pIndex}.stdRaw*1000)/1000;
%         outputArray{end, 6} = fitMean;
%         outputArray{end, 7} = round(results.channel(chIndex).peaks{pIndex}.rmsFit*1000)/1000;
%         outputArray{end, 8} = round(results.channel(chIndex).peaks{pIndex}.stdFit*1000)/1000;
%         outputArray{end, 9} = round(results.channel(chIndex).peaks{pIndex}.improvement*1000)/1000;
%     end
% end
% waitbar(0.9, wb, 'Saving Analysis File')
% analysisFilePath = [obj.path.datasetDir, 'AcetylineCellRMSJitter.mat'];
% save(analysisFilePath, '-struct', 'results')
% analysisDocPath = [obj.path.datasetDir, 'AcetylineCellRMSJitter.xlsx'];
% xlswrite(analysisDocPath, outputArray);
hold(ax,'off');
delete(wb)
msgbox('CompressPlotData_IFBC472_13_TMRingR40g200L3wg750_321');
end