% This function is used to analyze the laser jitter in the current active
% dataset - Jan 2015
function obj = LaserNoiseAnalysis(obj)
wb = waitbar(0, 'Laser Noise Analysis');
movegui(wb, 'center');

results = [];
outputFormat = {'Channel', 'Peak', 'Mean (raw)', 'raw RMS (pm)', 'raw STD (pm)', 'Mean (fit)', 'fit RMS (pm)', 'fit STD (pm)', 'Improvement %'};
outputArray = outputFormat;
% Get Laser Setting
results.laserSetting = [];
% Ger Data
for chIndex = 1:length(obj.datasetParams.includedChannel)
    waitbar((chIndex-1)/length(obj.datasetParams.includedChannel), wb);
    channel = obj.datasetParams.includedChannel(chIndex);
    results.channel(chIndex).channelNum = channel;
    for pIndex = 1:obj.datasetParams.numOfPeaks(channel)
        rawPeaks = [];
        fitPeaks = [];
        for scanNumber = obj.firstScanNumber:obj.lastScanNumber
            if ~any(scanNumber == obj.appParams.tempActiveChannelExcludedScans)
                rawPeaks = [rawPeaks, obj.dataset{channel, scanNumber}.peaks{pIndex}.peakWvl];
                fitPeaks = [fitPeaks, obj.dataset{channel, scanNumber}.peaks{pIndex}.fitPeakWvl];
            end
        end
        results.channel(chIndex).peaks{pIndex}.rawPeaks = rawPeaks;
        rawMean = mean(rawPeaks);
        results.channel(chIndex).peaks{pIndex}.meanRaw = rawMean;
        rawPeaksNorm = (rawPeaks - rawMean)*1000; %in pm
        results.channel(chIndex).peaks{pIndex}.rawPeaksNorm = rawPeaksNorm;
        results.channel(chIndex).peaks{pIndex}.rmsRaw = rms(rawPeaksNorm);
        results.channel(chIndex).peaks{pIndex}.stdRaw = std(rawPeaksNorm);
        
        results.channel(chIndex).peaks{pIndex}.fitPeaks = fitPeaks;
        fitMean = mean(fitPeaks);
        results.channel(chIndex).peaks{pIndex}.meanFit = fitMean;
        fitPeaksNorm = (fitPeaks - fitMean)*1000; % in pm
        results.channel(chIndex).peaks{pIndex}.fitPeaksNorm = fitPeaksNorm;
        results.channel(chIndex).peaks{pIndex}.rmsFit = rms(fitPeaksNorm);
        results.channel(chIndex).peaks{pIndex}.stdFit = std(fitPeaksNorm);
        
        results.channel(chIndex).peaks{pIndex}.improvement = (results.channel(chIndex).peaks{pIndex}.rmsFit - results.channel(chIndex).peaks{pIndex}.rmsRaw)*100/results.channel(chIndex).peaks{pIndex}.rmsRaw;
        
        outputArray{end + 1, 1} = channel;
        outputArray{end, 2} = pIndex;
        outputArray{end, 3} = rawMean;
        outputArray{end, 4} = round(results.channel(chIndex).peaks{pIndex}.rmsRaw*1000)/1000;
        outputArray{end, 5} = round(results.channel(chIndex).peaks{pIndex}.stdRaw*1000)/1000;
        outputArray{end, 6} = fitMean;
        outputArray{end, 7} = round(results.channel(chIndex).peaks{pIndex}.rmsFit*1000)/1000;
        outputArray{end, 8} = round(results.channel(chIndex).peaks{pIndex}.stdFit*1000)/1000;
        outputArray{end, 9} = round(results.channel(chIndex).peaks{pIndex}.improvement*1000)/1000;
    end
end
waitbar(0.9, wb, 'Saving Analysis File')
analysisFilePath = [obj.path.datasetDir, 'LaserNoiseAnalysis.mat'];
save(analysisFilePath, '-struct', 'results')
analysisDocPath = [obj.path.datasetDir, 'LaserNoiseAnalysis.xlsx'];
xlswrite(analysisDocPath, outputArray);
delete(wb)
msgbox('Laser Noise Analysis Finish!', 'Testbench Characterization');
end