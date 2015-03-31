% Flow Rate Charaterization - Vince Wu Feb 2015
wb = waitbar(0, 'Flow Rate Noise Analysis');
movegui(wb, 'center');
% File Paths
%    'C:\Users\vinic_000\Dropbox\BioBenchData\20150221_A1_TBcharDifferentFlowRatesIME\A1\27\Disk_293\BioAssay\2015.02.21@12.47\', ...
FilePath = {...
    'C:\Users\Shon\Dropbox (MLP)\BioBenchData\20150221_A1_TBcharDifferentFlowRatesIME\A1\27\Disk_293\BioAssay\2015.02.21@17.02\', ...
    'C:\Users\Shon\Dropbox (MLP)\BioBenchData\20150221_A1_TBcharDifferentFlowRatesIME\A1\27\Disk_293\BioAssay\2015.02.22@16.09\'};


% Output Format & Paths
outputDataPath = 'C:\Users\vinic_000\Dropbox\BioBenchData\20150221_A1_TBcharDifferentFlowRatesIME\A1\27\Disk_293\BioAssay\FlowRateCharacterizationAnalysis.mat';
outputTablePath = 'C:\Users\vinic_000\Dropbox\BioBenchData\20150221_A1_TBcharDifferentFlowRatesIME\A1\27\Disk_293\BioAssay\FlowRateCharacterizationAnalysis.xlsx';
outputTableFormat = {'Channel', 'Peak', 'Flow Rate (uL/min)', 'Jitter RMS (raw)', 'Jitter RMS (fit)', 'Noise Reduction %', 'Note', 'Dataset Link'};
outputTable = outputTableFormat;

Description = {...
    'Trial#1@12:47', ...
    'Trial#2@17.02', ...
    'Trial#3@16.09'};

numOfFile = length(FilePath);
referenceStruct = {[1, 1], [2, 1]; [1, 2], [2, 2]}; % [Ch, Peak]; 
numOfReference = size(referenceStruct, 1);

output = [];

% Generate structure of output file
thisFile =  [FilePath{1}, 'FlowRateCharacterizationAnalysis.mat'];
result = load(thisFile);
for chIndex = 1:length(result.channel)
    channel = result.channel(chIndex).channelNum;
    output.channel(chIndex).channelNum = channel;
    for pIndex = 1:length(result.channel(chIndex).peaks)
        output.channel(chIndex).peaks{pIndex}.flowRate = zeros(1, length(result.channel(chIndex).peaks{pIndex}.flowRate));
        output.channel(chIndex).peaks{pIndex}.reagent = cell(1, length(result.channel(chIndex).peaks{pIndex}.flowRate));
        output.channel(chIndex).peaks{pIndex}.rmsRaw = zeros(numOfFile, length(result.channel(chIndex).peaks{pIndex}.flowRate));
        output.channel(chIndex).peaks{pIndex}.stdRaw = zeros(numOfFile, length(result.channel(chIndex).peaks{pIndex}.flowRate));
        output.channel(chIndex).peaks{pIndex}.rmsFit = zeros(numOfFile, length(result.channel(chIndex).peaks{pIndex}.flowRate));
        output.channel(chIndex).peaks{pIndex}.stdFit = zeros(numOfFile, length(result.channel(chIndex).peaks{pIndex}.flowRate));
        for frIndex = 1:length(result.channel(chIndex).peaks{pIndex}.flowRate)
            flowRate_wRef = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).flowRateVal;
            output.channel(chIndex).peaks{pIndex}.flowRate(frIndex) = flowRate_wRef;
            output.channel(chIndex).peaks{pIndex}.reagent{frIndex} = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).reagent;
            rmsRaw = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rmsRaw;
            output.channel(chIndex).peaks{pIndex}.rmsRaw(1, frIndex) = rmsRaw;
            output.channel(chIndex).peaks{pIndex}.stdRaw(1, frIndex) = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).stdRaw;
            rmsFit = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rmsFit;
            output.channel(chIndex).peaks{pIndex}.rmsFit(1, frIndex) = rmsFit;
            output.channel(chIndex).peaks{pIndex}.stdFit(1, frIndex) = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).stdFit;
            
            if flowRate_wRef ~= 20
                outputTable{end + 1, 1} = channel;
                outputTable{end, 2} = pIndex;
                outputTable{end, 3} = flowRate_wRef;
                outputTable{end, 4} = rmsRaw;
                outputTable{end, 5} = rmsFit;
                outputTable{end, 6} = round(10000*(rmsFit - rmsRaw)/rmsRaw)/100;
                outputTable{end, 7} = Description{1};
                outputTable{end, 8} = FilePath{1};
            end
        end
    end
end
% Generate structure for output reference
for rfIndex = 1:numOfReference
    funcCh = referenceStruct{rfIndex, 1}(1);
    funcP = referenceStruct{rfIndex, 1}(2);
    refCh = referenceStruct{rfIndex, 2}(1);
    refP = referenceStruct{rfIndex, 2}(2);
    output.reference(rfIndex).note = sprintf('Ch#%dP%d - Ch#%dP%d', funcCh, funcP, refCh, refP);
    % Get the reference
    for chIndex = 1:length(result.channel)
        if result.channel(chIndex).channelNum == funcCh;
            break
        end
    end
    funcChIndex = chIndex;
    for chIndex = 1:length(result.channel)
        if result.channel(chIndex).channelNum == refCh;
            break
        end
    end
    refChIndex = chIndex;
    output.reference(rfIndex).flowRate(frIndex).rmsRaw = zeros(numOfFile, 1);
    output.reference(rfIndex).flowRate(frIndex).stdRaw = zeros(numOfFile, 1);
    output.reference(rfIndex).flowRate(frIndex).rmsFit = zeros(numOfFile, 1);
    output.reference(rfIndex).flowRate(frIndex).stdFit = zeros(numOfFile, 1);
    for frIndex = 1:length(result.channel(funcChIndex).peaks{funcP}.flowRate)
        output.reference(rfIndex).flowRate(frIndex).flowRate = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).flowRateVal;
        output.reference(rfIndex).flowRate(frIndex).reagent = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).reagent;
        rawPeaks = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rawPeaks - result.channel(refChIndex).peaks{refP}.flowRate(frIndex).rawPeaks;
        fitPeaks = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).fitPeaks - result.channel(refChIndex).peaks{refP}.flowRate(frIndex).fitPeaks;
        rawPeaksNorm = rawPeaks - mean(rawPeaks);
        fitPeaksNorm = fitPeaks - mean(fitPeaks);
        output.reference(rfIndex).flowRate(frIndex).rmsRaw(1) = rms(rawPeaksNorm);
        output.reference(rfIndex).flowRate(frIndex).stdRaw(1) = std(rawPeaksNorm);
        output.reference(rfIndex).flowRate(frIndex).rmsFit(1) = rms(fitPeaksNorm);
        output.reference(rfIndex).flowRate(frIndex).stdFit(1) = std(fitPeaksNorm);
    end
end

waitbar(1/numOfFile, wb)

% TEC state Analysis for the reference data
% output.TECstate(1).note = 'TEC on';
% output.TECstate(2).note = 'TEC off';

% Analysis
for fIndex = 2:numOfFile
    thisFile =  [FilePath{fIndex}, 'FlowRateCharacterizationAnalysis.mat'];
    result = load(thisFile);
    for chIndex = 1:length(result.channel)
        channel = result.channel(chIndex).channelNum;
        for pIndex = 1:length(result.channel(chIndex).peaks)
            for frIndex = 1:length(result.channel(chIndex).peaks{pIndex}.flowRate)
                rmsRaw = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rmsRaw;
                output.channel(chIndex).peaks{pIndex}.rmsRaw(fIndex, frIndex) = rmsRaw;
                output.channel(chIndex).peaks{pIndex}.stdRaw(fIndex, frIndex) = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).stdRaw;
                rmsFit = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).rmsFit;
                output.channel(chIndex).peaks{pIndex}.rmsFit(fIndex, frIndex) = rmsFit;
                output.channel(chIndex).peaks{pIndex}.stdFit(fIndex, frIndex) = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).stdFit;
                
                flowRate_wRef = result.channel(chIndex).peaks{pIndex}.flowRate(frIndex).flowRateVal;
                if flowRate_wRef ~= 20
                    outputTable{end + 1, 1} = channel;
                    outputTable{end, 2} = pIndex;
                    outputTable{end, 3} = flowRate_wRef;
                    outputTable{end, 4} = rmsRaw;
                    outputTable{end, 5} = rmsFit;
                    outputTable{end, 6} = round(10000*(rmsFit - rmsRaw)/rmsRaw)/100;
                    outputTable{end, 7} = Description{fIndex};
                    outputTable{end, 8} = FilePath{fIndex};
                end
            end
        end
    end
    % For Reference
    for rfIndex = 1:numOfReference
        funcCh = referenceStruct{rfIndex, 1}(1);
        funcP = referenceStruct{rfIndex, 1}(2);
        refCh = referenceStruct{rfIndex, 2}(1);
        refP = referenceStruct{rfIndex, 2}(2);
        output.reference(rfIndex).note = sprintf('Ch#%dP%d - Ch#%dP%d', funcCh, funcP, refCh, refP);
        % Get the reference
        for chIndex = 1:length(result.channel)
            if result.channel(chIndex).channelNum == funcCh;
                break
            end
        end
        funcChIndex = chIndex;
        for chIndex = 1:length(result.channel)
            if result.channel(chIndex).channelNum == refCh;
                break
            end
        end
        refChIndex = chIndex;
        for frIndex = 1:length(result.channel(funcChIndex).peaks{funcP}.flowRate)
            output.reference(rfIndex).flowRate(frIndex).flowRate = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).flowRateVal;
            output.reference(rfIndex).flowRate(frIndex).reagent = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).reagent;
            rawPeaks = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rawPeaks - result.channel(refChIndex).peaks{refP}.flowRate(frIndex).rawPeaks;
            fitPeaks = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).fitPeaks - result.channel(refChIndex).peaks{refP}.flowRate(frIndex).fitPeaks;
            rawPeaksNorm = rawPeaks - mean(rawPeaks);
            fitPeaksNorm = fitPeaks - mean(fitPeaks);
            output.reference(rfIndex).flowRate(frIndex).rmsRaw(fIndex) = rms(rawPeaksNorm);
            output.reference(rfIndex).flowRate(frIndex).stdRaw(fIndex) = std(rawPeaksNorm);
            output.reference(rfIndex).flowRate(frIndex).rmsFit(fIndex) = rms(fitPeaksNorm);
            output.reference(rfIndex).flowRate(frIndex).stdFit(fIndex) = std(fitPeaksNorm);
            
            output.TECstate(1).WOreference(rfIndex).note = sprintf('Ch#%dP%d', funcCh, funcP);
            output.TECstate(1).Wreference(rfIndex).note = output.reference(rfIndex).note;
            output.TECstate(2).WOreference(rfIndex).note = sprintf('Ch#%dP%d', funcCh, funcP);
            output.TECstate(2).Wreference(rfIndex).note = output.reference(rfIndex).note;
            % For TEC merging
            
            if ~strfind(Description{fIndex}, 'w/o TEC')
                output.TECstate(1).WOreference(rfIndex).flowRate(frIndex).flowRate = output.reference(rfIndex).flowRate(frIndex).flowRate;
                output.TECstate(1).Wreference(rfIndex).flowRate(frIndex).flowRate = output.reference(rfIndex).flowRate(frIndex).flowRate;
                if isfield(output.TECstate(1).WOreference(rfIndex).flowRate(frIndex), 'rmsRaw')
                    output.TECstate(1).WOreference(rfIndex).flowRate(frIndex).rmsRaw(end + 1) = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rmsRaw;
                    output.TECstate(1).WOreference(rfIndex).flowRate(frIndex).rmsFit(end + 1) = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rmsFit;
                    output.TECstate(1).Wreference(rfIndex).flowRate(frIndex).rmsRaw(end + 1) = output.reference(rfIndex).flowRate(frIndex).rmsRaw(fIndex);
                    output.TECstate(1).Wreference(rfIndex).flowRate(frIndex).rmsFit(end + 1) = output.reference(rfIndex).flowRate(frIndex).rmsFit(fIndex);
                else
                    output.TECstate(1).WOreference(rfIndex).flowRate(frIndex).rmsRaw = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rmsRaw;
                    output.TECstate(1).WOreference(rfIndex).flowRate(frIndex).rmsFit = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rmsFit;
                    output.TECstate(1).Wreference(rfIndex).flowRate(frIndex).rmsRaw = output.reference(rfIndex).flowRate(frIndex).rmsRaw(fIndex);
                    output.TECstate(1).Wreference(rfIndex).flowRate(frIndex).rmsFit = output.reference(rfIndex).flowRate(frIndex).rmsFit(fIndex);
                end
            elseif strfind(Description{fIndex}, 'w/o TEC')
                output.TECstate(2).WOreference(rfIndex).flowRate(frIndex).flowRate = output.reference(rfIndex).flowRate(frIndex).flowRate;
                output.TECstate(2).Wreference(rfIndex).flowRate(frIndex).flowRate = output.reference(rfIndex).flowRate(frIndex).flowRate;
                if isfield(output.TECstate(2).WOreference(rfIndex).flowRate(frIndex), 'rmsRaw')
                    output.TECstate(2).WOreference(rfIndex).flowRate(frIndex).rmsRaw(end + 1) = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rmsRaw;
                    output.TECstate(2).WOreference(rfIndex).flowRate(frIndex).rmsFit(end + 1) = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rmsFit;
                    output.TECstate(2).Wreference(rfIndex).flowRate(frIndex).rmsRaw(end + 1) = output.reference(rfIndex).flowRate(frIndex).rmsRaw(fIndex);
                    output.TECstate(2).Wreference(rfIndex).flowRate(frIndex).rmsFit(end + 1) = output.reference(rfIndex).flowRate(frIndex).rmsFit(fIndex);
                else
                    output.TECstate(2).WOreference(rfIndex).flowRate(frIndex).rmsRaw = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rmsRaw;
                    output.TECstate(2).WOreference(rfIndex).flowRate(frIndex).rmsFit = result.channel(funcChIndex).peaks{funcP}.flowRate(frIndex).rmsFit;
                    output.TECstate(2).Wreference(rfIndex).flowRate(frIndex).rmsRaw = output.reference(rfIndex).flowRate(frIndex).rmsRaw(fIndex);
                    output.TECstate(2).Wreference(rfIndex).flowRate(frIndex).rmsFit = output.reference(rfIndex).flowRate(frIndex).rmsFit(fIndex);
                end
            end
        end
    end
    
    waitbar(fIndex/numOfFile, wb)
end

for tec = 1:2
    for rfIndex = 1:numOfReference
        for frIndex = 1:length(result.channel(funcChIndex).peaks{funcP}.flowRate)
            if isfield(output.TECstate(tec).WOreference(rfIndex), 'flowRate')
                output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsRawMean = mean(output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsRaw);
                output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsRawStd = std(output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsRaw - output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsRawMean);
                output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsFitMean = mean(output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsFit);
                output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsFitStd = std(output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsFit - output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsFitMean);
            end
            if isfield(output.TECstate(tec).Wreference(rfIndex), 'flowRate')
                output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsRawMean = mean(output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsRaw);
                output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsRawStd = std(output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsRaw - output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsRawMean);
                output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsFitMean = mean(output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsFit);
                output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsFitStd = std(output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsFit - output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsFitMean);
            end
        end
    end
end

save(outputDataPath, '-struct', 'output')
xlswrite(outputTablePath, outputTable);

% Plotting Set#1
numOfFR = length(result.channel(1).peaks{1}.flowRate);
peakColor = {'r', 'b', 'k', 'm'};
peakShape = {'o', '^', 's', 'd'};
comb = [1:4, 1:4, 1:4, 1:4;1 2 3 4 2 3 4 1 3 4 1 2 4 1 2 3];
% Plot#1 - 3 - Plot the same peaks of each dataset in the same plot
% Plot#4 - 7 - Compare all data with flow rate = 0, 1, 10 and 100uL/min
for frIndex = 1:numOfFR
    flowRate_wRef = result.channel(1).peaks{1}.flowRate(frIndex).flowRateVal;
    summaryPlot(frIndex) = figure('Name', sprintf('Flow Rate Analysis - %duL/min', flowRate_wRef));
    summaryRaw(frIndex) = subplot(1, 2, 1); set(summaryRaw(frIndex), 'Parent', summaryPlot(frIndex)); hold(summaryRaw(frIndex), 'on');
    title(summaryRaw(frIndex), sprintf('Raw Data @ Flow Rate = %duL/min', flowRate_wRef))
    ylabel(summaryRaw(frIndex), 'RMS [pm]')
    summaryFit(frIndex) = subplot(1, 2, 2); set(summaryFit(frIndex), 'Parent', summaryPlot(frIndex)); hold(summaryFit(frIndex), 'on');
    title(summaryFit(frIndex), sprintf('Fitted Data @ Flow Rate = %duL/min', flowRate_wRef))
    ylabel(summaryFit(frIndex), 'RMS [pm]')
end
peakCount = 0;
peakLabel = {};
% Start Plotting
for chIndex = 1:length(output.channel)
    for pIndex = 1:length(output.channel(chIndex).peaks)
        peakCount = peakCount + 1;
        figure('Name', sprintf('Flow Rate Analysis - Channel #%d Peak #%d', output.channel(chIndex).channelNum, pIndex));
        
        % Plot #1
        subplot(1, 2, 1);
        hold on
        for fIndex = 1:numOfFile
            plot(output.channel(chIndex).peaks{pIndex}.flowRate(2:end), output.channel(chIndex).peaks{pIndex}.rmsRaw(fIndex, 2:end)*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}], 'MarkerSize', 8);
        end
        legend(Description);
        %         for fIndex = 1:numOfFile
        %             errorbar(output.channel(chIndex).peaks{pIndex}.flowRate, output.channel(chIndex).peaks{pIndex}.rmsRaw(fIndex, :), output.channel(chIndex).peaks{pIndex}.stdRaw(fIndex, :)/2, [peakColor{comb(1, fIndex)}, '--']);
        %         end
        title(sprintf('Channel#%d Peak#%d Raw Data', output.channel(chIndex).channelNum, pIndex))
        set(gca, 'XTick', [0, 1, 10, 100])
        xlabel('Flow Rate [uL/min]')
        ylabel('RMS [pm]')
        hold off
        
        % Plot #2
        subplot(1, 2, 2);
        hold on
        for fIndex = 1:numOfFile
            plot(output.channel(chIndex).peaks{pIndex}.flowRate(2:end), output.channel(chIndex).peaks{pIndex}.rmsFit(fIndex, 2:end)*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}], 'MarkerSize', 8)
        end
        legend(Description);
        %         for fIndex = 1:numOfFile
        %             errorbar(output.channel(chIndex).peaks{pIndex}.flowRate, output.channel(chIndex).peaks{pIndex}.rmsFit(fIndex, :), output.channel(chIndex).peaks{pIndex}.stdFit(fIndex, :)/2, [peakColor{comb(1, fIndex)}, '--']);
        %         end
        title(sprintf('Channel#%d Peak#%d Fit Data', output.channel(chIndex).channelNum, pIndex))
        set(gca, 'XTick', [0, 1, 10, 100])
        xlabel('Flow Rate [uL/min]')
        ylabel('RMS [pm]')
        hold off
        
        % Plot #4 - 7
        for frIndex = 1:numOfFR
            for fIndex = 1:numOfFile
                plot(summaryRaw(frIndex), peakCount, output.channel(chIndex).peaks{pIndex}.rmsRaw(fIndex, frIndex)*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}], 'MarkerSize', 8, 'LineWidth', 2);
                plot(summaryFit(frIndex), peakCount, output.channel(chIndex).peaks{pIndex}.rmsFit(fIndex, frIndex)*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}], 'MarkerSize', 8, 'LineWidth', 2);
            end
        end
        peakLabel{peakCount} = sprintf('Ch#%dP%d', output.channel(chIndex).channelNum, pIndex);
    end
end
for frIndex = 1:numOfFR
    legend(summaryRaw(frIndex), Description, 'Location', 'Best');
    legend(summaryFit(frIndex), Description, 'Location', 'Best');
    set(summaryRaw(frIndex), 'XTick', 1:peakCount)
    set(summaryFit(frIndex), 'XTick', 1:peakCount)
    set(summaryRaw(frIndex), 'XTickLabel', peakLabel);
    set(summaryFit(frIndex), 'XTickLabel', peakLabel);
end

% Plotting Set#2 - Reference Plotting
if isfield(output.TECstate(tec).WOreference(rfIndex), 'flowRate') && isfield(output.TECstate(tec).Wreference(rfIndex), 'flowRate')
peakColor = {'r', 'b'};
peakShape = {'o', '^'};
% Plot #8 - 11: 
% Plot #12 - 15:
tecLabel = {'TEC on', 'TEC off'};
peakLabelWORf = {};
pealLabelWRf = {};
for frIndex = 1:numOfFR
    flowRate_wRef = result.channel(1).peaks{1}.flowRate(frIndex).flowRateVal;
    summaryPlotWORf(frIndex) = figure('Name', sprintf('Flow Rate & TEC Analysis w/o Reference - %duL/min', flowRate_wRef));
    summaryRawWORf(frIndex) = subplot(1, 2, 1); set(summaryRawWORf(frIndex), 'Parent', summaryPlotWORf(frIndex)); hold(summaryRawWORf(frIndex), 'on');
    title(summaryRawWORf(frIndex), sprintf('Raw Data @ Flow Rate = %duL/min w/o Reference', flowRate_wRef))
    ylabel(summaryRawWORf(frIndex), 'RMS [pm]')
    summaryFitWORf(frIndex) = subplot(1, 2, 2); set(summaryFitWORf(frIndex), 'Parent', summaryPlotWORf(frIndex)); hold(summaryFitWORf(frIndex), 'on');
    title(summaryFitWORf(frIndex), sprintf('Fitted Data @ Flow Rate = %duL/min w/o Reference', flowRate_wRef))
    ylabel(summaryFitWORf(frIndex), 'RMS [pm]')
    
    summaryPlotWRf(frIndex) = figure('Name', sprintf('Flow Rate & TEC Analysis w/ Reference - %duL/min', flowRate_wRef));
    summaryRawWRf(frIndex) = subplot(1, 2, 1); set(summaryRawWRf(frIndex), 'Parent', summaryPlotWRf(frIndex)); hold(summaryRawWRf(frIndex), 'on');
    title(summaryRawWRf(frIndex), sprintf('Raw Data @ Flow Rate = %duL/min w/ Reference', flowRate_wRef))
    ylabel(summaryRawWRf(frIndex), 'RMS [pm]')
    summaryFitWRf(frIndex) = subplot(1, 2, 2); set(summaryFitWRf(frIndex), 'Parent', summaryPlotWRf(frIndex)); hold(summaryFitWRf(frIndex), 'on');
    title(summaryFitWRf(frIndex), sprintf('Fitted Data @ Flow Rate = %duL/min w/ Reference', flowRate_wRef))
    ylabel(summaryFitWRf(frIndex), 'RMS [pm]')
    
    for rfIndex = 1:numOfReference
        for tec = 1:2 % 1 - on, 2 - off
            plot(summaryRawWORf(frIndex), rfIndex, output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsRawMean*1000, [peakColor{tec}, peakShape{tec}], 'MarkerSize', 8, 'LineWidth', 2);
            plot(summaryFitWORf(frIndex), rfIndex, output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsFitMean*1000, [peakColor{tec}, peakShape{tec}], 'MarkerSize', 8, 'LineWidth', 2);
            plot(summaryRawWRf(frIndex), rfIndex, output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsRawMean*1000, [peakColor{tec}, peakShape{tec}], 'MarkerSize', 8, 'LineWidth', 2);
            plot(summaryFitWRf(frIndex), rfIndex, output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsFitMean*1000, [peakColor{tec}, peakShape{tec}], 'MarkerSize', 8, 'LineWidth', 2);
        end
        % Do this in order to correctly label legend --- start ---
        if rfIndex == 1
            legend(summaryRawWORf(frIndex), tecLabel, 'Location', 'Best');
            legend(summaryFitWORf(frIndex), tecLabel, 'Location', 'Best');
            legend(summaryRawWRf(frIndex), tecLabel, 'Location', 'Best');
            legend(summaryFitWRf(frIndex), tecLabel, 'Location', 'Best');
        end
        % Do this in order to correctly label legend --- end ---
        % Plot error bar
        for tec = 1:2 % 1 - on, 2 - off
            if length(output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsRaw) > 1
                errorbar(summaryRawWORf(frIndex), rfIndex, output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsRawMean*1000, output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsRawStd*1000/2, peakColor{tec});
                errorbar(summaryFitWORf(frIndex), rfIndex, output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsFitMean*1000, output.TECstate(tec).WOreference(rfIndex).flowRate(frIndex).rmsFitStd*1000/2, peakColor{tec});
            end
            if length(output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsRaw) > 1
                errorbar(summaryRawWRf(frIndex), rfIndex, output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsRawMean*1000, output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsRawStd*1000/2, peakColor{tec});
                errorbar(summaryFitWRf(frIndex), rfIndex, output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsFitMean*1000, output.TECstate(tec).Wreference(rfIndex).flowRate(frIndex).rmsFitStd*1000/2, peakColor{tec});
            end
        end
        % ------
        if frIndex == 1
            peakLabelWORf{rfIndex} = output.TECstate(1).WOreference(rfIndex).note;
            peakLabelWRf{rfIndex} = output.TECstate(1).Wreference(rfIndex).note;
        end
    end
    set(summaryRawWORf(frIndex), 'XTick', 1:numOfReference)
    set(summaryFitWORf(frIndex), 'XTick', 1:numOfReference)
    set(summaryRawWORf(frIndex), 'XTickLabel', peakLabelWORf);
    set(summaryFitWORf(frIndex), 'XTickLabel', peakLabelWORf);
    
    set(summaryRawWRf(frIndex), 'XTick', 1:numOfReference)
    set(summaryFitWRf(frIndex), 'XTick', 1:numOfReference)
    set(summaryRawWRf(frIndex), 'XTickLabel', peakLabelWRf);
    set(summaryFitWRf(frIndex), 'XTickLabel', peakLabelWRf);
end
end

% Plot #16: Plot RMS vs. FlowRate using the fitted and referenced peak
peakColor = {'r', 'b', 'k'};
peakShape = {'o', '^', 's'};

bestF_wRef = figure('Name', 'Flow Rate Analysis - Fitted Peaks w/ Reference');
bestA_wRef = axes('Parent', bestF_wRef);
xlabel(bestA_wRef, 'Flow Rate [uL/min]');
ylabel(bestA_wRef, 'RMS [pm]')
hold(bestA_wRef, 'on')

bestF_woRef = figure('Name', 'Flow Rate Analysis - Fitted Peaks w/o Reference');
bestA_woRef = axes('Parent', bestF_woRef);
xlabel(bestA_woRef, 'Flow Rate [uL/min]');
ylabel(bestA_woRef, 'RMS [pm]')
hold(bestA_woRef, 'on')

legendS_wRef = cell(1, numOfReference);
legendS_woRef = cell(1, numOfReference);
xTickLablS = cell(1, numOfFR - 1);
flowRate_wRef = zeros(numOfReference, numOfFR);
rmsFitData_wRef = zeros(numOfReference, numOfFR);
stdFitData_wRef = zeros(numOfReference, numOfFR);
flowRate_woRef = zeros(numOfReference, numOfFR);
rmsFitData_woRef = zeros(numOfReference, numOfFR);
stdFitData_woRef = zeros(numOfReference, numOfFR);
for rf = 1:numOfReference
    for fr = 1:numOfFR
        flowRate_wRef(rf, fr) = output.TECstate(1).Wreference(rf).flowRate(fr).flowRate;
        rmsFitData_wRef(rf, fr) = output.TECstate(1).Wreference(rf).flowRate(fr).rmsFitMean;
        stdFitData_wRef(rf, fr) = output.TECstate(1).Wreference(rf).flowRate(fr).rmsFitStd;
        flowRate_woRef(rf, fr) = output.TECstate(1).WOreference(rf).flowRate(fr).flowRate;
        rmsFitData_woRef(rf, fr) = output.TECstate(1).WOreference(rf).flowRate(fr).rmsFitMean;
        stdFitData_woRef(rf, fr) = output.TECstate(1).WOreference(rf).flowRate(fr).rmsFitStd;
        if fr > 1
            xTickLablS{fr-1} = num2str(output.TECstate(1).Wreference(rf).flowRate(fr).flowRate);
        end
    end
    plot(bestA_wRef, [0.1, flowRate_wRef(rf, 3:end)], rmsFitData_wRef(rf, 2:end)*1000, [peakColor{rf}, peakShape{rf}], 'MarkerSize', 8, 'LineWidth', 2);
    plot(bestA_woRef, [0.1, flowRate_woRef(rf, 3:end)], rmsFitData_woRef(rf, 2:end)*1000, [peakColor{rf}, peakShape{rf}], 'MarkerSize', 8, 'LineWidth', 2);
    legendS_wRef{rf} = output.TECstate(1).Wreference(rf).note;
    legendS_woRef{rf} = output.TECstate(1).WOreference(rf).note;
end
legend(bestA_wRef, legendS_wRef, 'Location', 'Best');
legend(bestA_woRef, legendS_woRef, 'Location', 'Best');
for rf = 1:numOfReference
    errorbar(bestA_wRef, [0.1, flowRate_wRef(rf, 3:end)], rmsFitData_wRef(rf, 2:end)*1000, stdFitData_wRef(rf, 2:end)*1000/2, peakColor{rf}, 'LineStyle', 'none');
    errorbar(bestA_woRef, [0.1, flowRate_wRef(rf, 3:end)], rmsFitData_woRef(rf, 2:end)*1000, stdFitData_woRef(rf, 2:end)*1000/2, peakColor{rf}, 'LineStyle', 'none');
end
set(bestA_wRef, 'XTick', [0.1, flowRate_wRef(1, 3:end)]);
set(bestA_wRef, 'XScale', 'log');
set(bestA_wRef, 'XTickLabel', xTickLablS);
hold(bestA_wRef, 'off')

set(bestA_woRef, 'XTick', [0.1, flowRate_woRef(1, 3:end)]);
set(bestA_woRef, 'XScale', 'log');
set(bestA_woRef, 'XTickLabel', xTickLablS);
hold(bestA_woRef, 'off')

% Plot #17
% fr10CompareF = figure('Name', 'Flow Rate Analysis (TEC & Reference) - 10uL/min');
% fr10Index = 3;
% tickLabels = {sprintf('TEC off & w/o Ref'), sprintf('TEC on & w/o Ref'), sprintf('TEC off & w/ Ref'), sprintf('TEC on & w/ Ref')};
% 
% % Subplot 1 Raw Data
% fr10CompareRawA = subplot(1, 2, 1);
% set(fr10CompareRawA, 'Parent', fr10CompareF);
% title(fr10CompareRawA, 'Raw Data')
% ylabel(fr10CompareRawA, 'RMS [pm]')
% hold(fr10CompareRawA, 'on')
% % RMS
% plot(fr10CompareRawA, 1, output.TECstate(2).WOreference(2).flowRate(fr10Index).rmsRawMean*1000, 'ko', 'MarkerSize', 8, 'LineWidth', 2) % TEC off, w/o Ref, second peak
% plot(fr10CompareRawA, 2, output.TECstate(1).WOreference(2).flowRate(fr10Index).rmsRawMean*1000, 'ko', 'MarkerSize', 8, 'LineWidth', 2) % TEC on, w/o Ref, second peak
% plot(fr10CompareRawA, 3, output.TECstate(2).Wreference(2).flowRate(fr10Index).rmsRawMean*1000, 'ko', 'MarkerSize', 8, 'LineWidth', 2) % TEC off, w/ Ref, second peak
% plot(fr10CompareRawA, 4, output.TECstate(1).Wreference(2).flowRate(fr10Index).rmsRawMean*1000, 'ko', 'MarkerSize', 8, 'LineWidth', 2) % TEC on, w/ Ref, second peak
% % STD
% errorbar(fr10CompareRawA, 2, output.TECstate(1).WOreference(2).flowRate(fr10Index).rmsRawMean*1000, output.TECstate(1).WOreference(2).flowRate(fr10Index).rmsRawStd*1000/2, 'k', 'LineStyle', 'none') % TEC on, w/o Ref, second peak
% errorbar(fr10CompareRawA, 4, output.TECstate(1).Wreference(2).flowRate(fr10Index).rmsRawMean*1000, output.TECstate(1).Wreference(2).flowRate(fr10Index).rmsRawStd*1000/2, 'k', 'LineStyle', 'none') % TEC on, w/ Ref, second peak
% set(fr10CompareRawA, 'XTick', 1:4);
% set(fr10CompareRawA, 'XTickLabel', tickLabels);
% hold(fr10CompareRawA, 'off')
% 
% % Subplot 2 Fitted Data
% fr10CompareFitA = subplot(1, 2, 2);
% set(fr10CompareFitA, 'Parent', fr10CompareF);
% title(fr10CompareFitA, 'Fitted Data')
% ylabel(fr10CompareFitA, 'RMS [pm]')
% hold(fr10CompareFitA, 'on')
% % RMS
% plot(fr10CompareFitA, 1, output.TECstate(2).WOreference(2).flowRate(fr10Index).rmsFitMean*1000, 'ko', 'MarkerSize', 8, 'LineWidth', 2) % TEC off, w/o Ref, second peak
% plot(fr10CompareFitA, 2, output.TECstate(1).WOreference(2).flowRate(fr10Index).rmsFitMean*1000, 'ko', 'MarkerSize', 8, 'LineWidth', 2) % TEC on, w/o Ref, second peak
% plot(fr10CompareFitA, 3, output.TECstate(2).Wreference(2).flowRate(fr10Index).rmsFitMean*1000, 'ko', 'MarkerSize', 8, 'LineWidth', 2) % TEC off, w/ Ref, second peak
% plot(fr10CompareFitA, 4, output.TECstate(1).Wreference(2).flowRate(fr10Index).rmsFitMean*1000, 'ko', 'MarkerSize', 8, 'LineWidth', 2) % TEC on, w/ Ref, second peak
% % STD
% errorbar(fr10CompareFitA, 2, output.TECstate(1).WOreference(2).flowRate(fr10Index).rmsFitMean*1000, output.TECstate(1).WOreference(2).flowRate(fr10Index).rmsFitStd*1000/2, 'k', 'LineStyle', 'none') % TEC on, w/o Ref, second peak
% errorbar(fr10CompareFitA, 4, output.TECstate(1).Wreference(2).flowRate(fr10Index).rmsFitMean*1000, output.TECstate(1).Wreference(2).flowRate(fr10Index).rmsFitStd*1000/2, 'k', 'LineStyle', 'none') % TEC on, w/ Ref, second peak
% set(fr10CompareFitA, 'XTick', 1:4);
% set(fr10CompareFitA, 'XTickLabel', tickLabels);
% hold(fr10CompareFitA, 'off')

delete(wb)

% % Reference Analysis
% refPeakResultFig = figure('Name', 'Reference within Channel Results');
% refPeakResultSubAX(1) = subplot(2, 2, 1); hold(refPeakResultSubAX(1), 'on');
% refPeakResultSubAX(2) = subplot(2, 2, 2); hold(refPeakResultSubAX(2), 'on');
% refPeakResultSubAX(3) = subplot(2, 2, 3); hold(refPeakResultSubAX(3), 'on');
% refPeakResultSubAX(4) = subplot(2, 2, 4); hold(refPeakResultSubAX(4), 'on');
% refPeakFig = figure('Name', 'Flow Rate Analysis - Reference within Channel');
% refPeakSubAX(1) = subplot(2, 2, 1); hold(refPeakSubAX(1), 'on');
% refPeakSubAX(2) = subplot(2, 2, 2); hold(refPeakSubAX(2), 'on');
% refPeakSubAX(3) = subplot(2, 2, 3); hold(refPeakSubAX(3), 'on');
% refPeakSubAX(4) = subplot(2, 2, 4); hold(refPeakSubAX(4), 'on');
% refChannelResultFig = figure('Name', 'Reference different Channel Results');
% refChannelResultSubAX(1) = subplot(2, 2, 1); hold(refChannelResultSubAX(1), 'on');
% refChannelResultSubAX(2) = subplot(2, 2, 2); hold(refChannelResultSubAX(2), 'on');
% refChannelResultSubAX(3) = subplot(2, 2, 3); hold(refChannelResultSubAX(3), 'on');
% refChannelResultSubAX(4) = subplot(2, 2, 4); hold(refChannelResultSubAX(4), 'on');
% refChannelFig = figure('Name', 'Flow Rate Analysis - Peaks in different Channels');
% refChannelSubAX(1) = subplot(2, 2, 1); hold(refChannelSubAX(1), 'on');
% refChannelSubAX(2) = subplot(2, 2, 2); hold(refChannelSubAX(2), 'on');
% refChannelSubAX(3) = subplot(2, 2, 3); hold(refChannelSubAX(3), 'on');
% refChannelSubAX(4) = subplot(2, 2, 4); hold(refChannelSubAX(4), 'on');
% for fIndex = 1:numOfFile
%     thisFile =  [FilePath{fIndex}, 'FlowRateCharacterizationAnalysis.mat'];
%     result = load(thisFile);
%     %- 1. Reference between peaks in the same channel
%     for chIndex = 1:2
%         refPeakRawTotal = [];
%         refPeakFitTotal = [];
%         rmsRefRaw = [];
%         rmsRefFit = [];
%         for frIndex = 2:length(result.channel(chIndex).peaks{1}.flowRate)
%             refPeakRaw = result.channel(chIndex).peaks{1}.flowRate(frIndex).rawPeaks - result.channel(chIndex).peaks{2}.flowRate(frIndex).rawPeaks;
%             refPeakRawMean = mean(refPeakRaw);
%             refPeakRawNorm = refPeakRaw - refPeakRawMean;
%             refPeakRawRMS = rms(refPeakRawNorm);
%             refPeakRawSTD = std(refPeakRawNorm);
%             rmsRefRaw = [rmsRefRaw, refPeakRawRMS];
%             refPeakRawTotal = [refPeakRawTotal, refPeakRawNorm];
%
%             refPeakFit = result.channel(chIndex).peaks{1}.flowRate(frIndex).fitPeaks - result.channel(chIndex).peaks{2}.flowRate(frIndex).fitPeaks;
%             refPeakFitMean = mean(refPeakFit);
%             refPeakFitNorm = refPeakFit - refPeakFitMean;
%             refPeakFitRMS = rms(refPeakFitNorm);
%             refPeakFitSTD = std(refPeakFitNorm);
%             rmsRefFit = [rmsRefFit, refPeakFitRMS];
%             refPeakFitTotal = [refPeakFitTotal, refPeakFitNorm];
%         end
%         plot(refPeakResultSubAX(2*chIndex-1), refPeakRawTotal*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}, '-']);
%         title(refPeakResultSubAX(2*chIndex-1), sprintf('Channel#%d: Peak#1 - Peak#2 Raw Data', output.channel(chIndex).channelNum))
%         xlabel(refPeakResultSubAX(2*chIndex-1), 'Scan Number')
%         ylabel(refPeakResultSubAX(2*chIndex-1), 'Shift Difference [pm]')
%
%         plot(refPeakSubAX(2*chIndex-1), output.channel(chIndex).peaks{1}.flowRate(2:end), rmsRefRaw*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}, '--'], 'MarkerSize', 8);
%         title(refPeakSubAX(2*chIndex-1), sprintf('Channel#%d: Peak#1 - Peak#2 Raw Data', output.channel(chIndex).channelNum))
%         xlabel(refPeakSubAX(2*chIndex-1), 'Flow Rate [uL/min]')
%         ylabel(refPeakSubAX(2*chIndex-1), 'RMS [pm]')
%
%         plot(refPeakResultSubAX(2*chIndex), refPeakFitTotal*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}, '-']);
%         title(refPeakResultSubAX(2*chIndex), sprintf('Channel#%d: Peak#1 - Peak#2 Fit Data', output.channel(chIndex).channelNum))
%         xlabel(refPeakResultSubAX(2*chIndex), 'Scan Number')
%         ylabel(refPeakResultSubAX(2*chIndex), 'Shift Difference [pm]')
%
%         plot(refPeakSubAX(2*chIndex), output.channel(chIndex).peaks{1}.flowRate(2:end), rmsRefRaw*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}, '--'], 'MarkerSize', 8);
%         title(refPeakSubAX(2*chIndex), sprintf('Channel#%d: Peak#1 - Peak#2 Fit Data', output.channel(chIndex).channelNum))
%         xlabel(refPeakSubAX(2*chIndex), 'Flow Rate [uL/min]')
%         ylabel(refPeakSubAX(2*chIndex), 'RMS [pm]')
%     end
%     %- 2. Reference between peaks in different channels
%     for pIndex = 1:2
%         refPeakRawTotal = [];
%         refPeakFitTotal = [];
%         rmsRefRaw = [];
%         rmsRefFit = [];
%         for frIndex = 2:length(result.channel(1).peaks{pIndex}.flowRate)
%             fIndex
%             pIndex
%             frIndex
%             refPeakRaw = result.channel(1).peaks{pIndex}.flowRate(frIndex).rawPeaks - result.channel(2).peaks{pIndex}.flowRate(frIndex).rawPeaks;
%             refPeakRawMean = mean(refPeakRaw);
%             refPeakRawNorm = refPeakRaw - refPeakRawMean;
%             refPeakRawRMS = rms(refPeakRawNorm);
%             refPeakRawSTD = std(refPeakRawNorm);
%             rmsRefRaw = [rmsRefRaw, refPeakRawRMS];
%             refPeakRawTotal = [refPeakRawTotal, refPeakRawNorm];
%
%             refPeakFit = result.channel(1).peaks{pIndex}.flowRate(frIndex).fitPeaks - result.channel(2).peaks{pIndex}.flowRate(frIndex).fitPeaks;
%             refPeakFitMean = mean(refPeakFit);
%             refPeakFitNorm = refPeakFit - refPeakFitMean;
%             refPeakFitRMS = rms(refPeakFitNorm);
%             refPeakFitSTD = std(refPeakFitNorm);
%             rmsRefFit = [rmsRefFit, refPeakFitRMS];
%             refPeakFitTotal = [refPeakFitTotal, refPeakFitNorm];
%         end
%         plot(refChannelResultSubAX(2*pIndex-1), refPeakRawTotal*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}, '-']);
%         title(refChannelResultSubAX(2*pIndex-1), sprintf('Peak#%d: Channel#1 - Channel#2 Raw Data', pIndex))
%         xlabel(refChannelResultSubAX(2*pIndex-1), 'Scan Number')
%         ylabel(refChannelResultSubAX(2*pIndex-1), 'Shift Difference [pm]')
%
%         plot(refChannelSubAX(2*pIndex-1), output.channel(1).peaks{pIndex}.flowRate(2:end), rmsRefRaw*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}, '--'], 'MarkerSize', 8);
%         title(refChannelSubAX(2*pIndex-1), sprintf('Peak#%d: Channel#1 - Channel#2 Raw Data', pIndex))
%         xlabel(refChannelSubAX(2*pIndex-1), 'Flow Rate [uL/min]')
%         ylabel(refChannelSubAX(2*pIndex-1), 'RMS [pm]')
%
%         plot(refChannelResultSubAX(2*pIndex), refPeakFitTotal*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}, '-']);
%         title(refChannelResultSubAX(2*pIndex), sprintf('Peak#%d: Channel#1 - Channel#2 Fit Data', pIndex))
%         xlabel(refChannelResultSubAX(2*pIndex), 'Scan Number')
%         ylabel(refChannelResultSubAX(2*pIndex), 'Shift Difference [pm]')
%
%         plot(refChannelSubAX(2*pIndex), output.channel(1).peaks{pIndex}.flowRate(2:end), rmsRefRaw*1000, [peakColor{comb(1, fIndex)}, peakShape{comb(2, fIndex)}, '--'], 'MarkerSize', 8);
%         title(refChannelSubAX(2*pIndex), sprintf('Peak#%d: Channel#1 - Channel#2 Fit Data', pIndex))
%         xlabel(refChannelSubAX(2*pIndex), 'Flow Rate [uL/min]')
%         ylabel(refChannelSubAX(2*pIndex), 'RMS [pm]')
%     end
%     %- 3. Acetylene Cell Laser Jitter
%
% end
% for l = 1:length(refPeakSubAX)
%     legend(refPeakResultSubAX(l), Description);
%     legend(refPeakSubAX(l), Description);
% end
% for l = 1:length(refChannelSubAX)
%     legend(refChannelResultSubAX(l), Description);
%     legend(refChannelSubAX(l), Description);
% end
% % End of Reference Analysis