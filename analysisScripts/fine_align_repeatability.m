% This function is used to analyze test 4.1. repeatability of fine align
function obj = fine_align_repeatability(obj)
wb = waitbar(0, 'fine align testing...');
movegui(wb, 'center');

%peak fitting done on 40nm window -> GC spectrum, record peak value.
active_channel = 2; 

results = [];
outputFormat = {'Channel', 'Peak', 'Mean (raw)', 'raw RMS (pm)', 'raw STD (pm)', 'Mean (fit)', 'fit RMS (pm)', 'fit STD (pm)', 'Improvement %'};
outputArray = outputFormat;
% Get Laser Setting
results.laserSetting = [];
% Get Data
%there is data only in channel 2
chIndex = 1; %only one channel to test -> used to save results
channel = 2; %data is in channel 2
    results.channel(chIndex).channelNum = channel;
    for pIndex = 1:obj.datasetParams.numOfPeaks(channel)
        rawPeaks = [];
        fitPeaks = [];
        rawPeaks_pwr = [];
        fitPeaks_pwr = [];
        
        for scanNumber = obj.firstScanNumber:obj.lastScanNumber
            if ~any(scanNumber == obj.appParams.tempActiveChannelExcludedScans)
                rawPeaks = [rawPeaks, obj.dataset{channel, scanNumber}.peaks{pIndex}.peakWvl];
                fitPeaks = [fitPeaks, obj.dataset{channel, scanNumber}.peaks{pIndex}.fitPeakWvl];
                rawPeaks_pwr = [rawPeaks_pwr, obj.dataset{channel, scanNumber}.peaks{pIndex}.peakPwr];
                fitPeaks_pwr = [fitPeaks_pwr, obj.dataset{channel, scanNumber}.peaks{pIndex}.fitPeakPwr];
            end
            waitbar((scanNumber/obj.lastScanNumber), wb);
        end
        results.channel(chIndex).peaks{pIndex}.rawPeaks = rawPeaks;
        results.channel(chIndex).peaks{pIndex}.rawPeaks_pwr = rawPeaks_pwr;
        rawMean = mean(rawPeaks);
        rawMean_pwr = mean(rawPeaks_pwr); 
        results.channel(chIndex).peaks{pIndex}.meanRaw = rawMean;
        results.channel(chIndex).peaks{pIndex}.meanRaw_pwr = rawMean_pwr;
        rawPeaksNorm = (rawPeaks - rawMean)*1000; %in pm
        results.channel(chIndex).peaks{pIndex}.rawPeaksNorm = rawPeaksNorm;
        results.channel(chIndex).peaks{pIndex}.rmsRaw = rms(rawPeaksNorm);
        results.channel(chIndex).peaks{pIndex}.stdRaw = std(rawPeaksNorm);
        rawPeaksNorm_pwr = (rawPeaks_pwr - rawMean_pwr); 
        results.channel(chIndex).peaks{pIndex}.rawPeaksNorm_pwr = rawPeaksNorm_pwr;
        results.channel(chIndex).peaks{pIndex}.rmsRaw_pwr = rms(rawPeaksNorm_pwr);
        results.channel(chIndex).peaks{pIndex}.stdRaw_pwr = std(rawPeaks_pwr);
        
        results.channel(chIndex).peaks{pIndex}.fitPeaks = fitPeaks;
        results.channel(chIndex).peaks{pIndex}.fitPeaks_pwr = fitPeaks_pwr;
        fitMean = mean(fitPeaks);
        fitMean_pwr = mean(fitPeaks_pwr);
        results.channel(chIndex).peaks{pIndex}.meanFit = fitMean;
        results.channel(chIndex).peaks{pIndex}.meanFit_pwr = fitMean_pwr;
        fitPeaksNorm = (fitPeaks - fitMean)*1000; % in pm
        results.channel(chIndex).peaks{pIndex}.fitPeaksNorm = fitPeaksNorm;
        results.channel(chIndex).peaks{pIndex}.rmsFit = rms(fitPeaksNorm);
        results.channel(chIndex).peaks{pIndex}.stdFit = std(fitPeaksNorm);
        fitPeaksNorm_pwr = (fitPeaks_pwr - fitMean_pwr); % in pm
        results.channel(chIndex).peaks{pIndex}.fitPeaksNorm = fitPeaksNorm_pwr;
        results.channel(chIndex).peaks{pIndex}.rmsFit_pwr = rms(fitPeaksNorm_pwr);
        results.channel(chIndex).peaks{pIndex}.stdFit_pwr = std(fitPeaks_pwr);
        
    end

    f_fine = figure; 
    hold on; 
    plot(1:length(rawPeaks_pwr),rawPeaks_pwr,...
        'MarkerFaceColor','k',...
        'Marker','+'); 
    %plot(1:length(fitPeaks_pwr),fitPeaks_pwr); 
    xlabel('Iteration'); 
    ylabel('Insertion loss [dBm]'); 
    
    disp('std value of max power transmitted');
    disp(strcat(' = ', num2str(std(rawPeaks_pwr))));
    ind = find(abs(rawPeaks_pwr-rawMean_pwr)<3);
    size(ind)
    size(rawPeaks_pwr)
    rawPeaks_pwr = rawPeaks_pwr(ind); 
    rawMean_pwr = mean(rawPeaks_pwr); 
    disp('std value adjusted');
    disp(strcat(' = ', num2str(std(rawPeaks_pwr))));
    
waitbar(0.9, wb, 'Saving Analysis File')
analysisFilePath = [obj.path.datasetDir, 'FineAlignAnalysis.mat'];
save(analysisFilePath, '-struct', 'results')
%analysisDocPath = [obj.path.datasetDir, 'LaserNoiseAnalysis.xlsx'];
%xlswrite(analysisDocPath, outputArray);
delete(wb)
msgbox('Fine Align Analysis Finish!', 'Testbench Characterization');
end