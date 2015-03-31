% Vince Wu 04/05/2014
% Analysis Information
rootPath = 'C:\Users\Jonas\Dropbox\SiPhotonics\loss_data_analysis\EB';
chip = '447Q2L';
LossDeviceKeyWord = 'PropagationLoss';
die = 'A';
mode = 'TM1550';
testType = 'DryTest';
%testTimeStamp = '2014.06.25@23.12';
testTimeStamp = '2014.09.09@09.30';
file = {'Scan1.mat', 'Scan2.mat'};
peakWindow = [1500 1570]; %nm

outputFormat = 'pdf';
parentPath = strcat(rootPath, '\', chip, '\', die, '\');

option = struct(...
    'format', outputFormat, ...
    'outputDir', parentPath, ...
    'showCode', false, ...
    'codeToEvaluate', 'PropagationLossAnalysis(parentPath, LossDeviceKeyWord, mode, testType, testTimeStamp, file, peakWindow)');

publish('PropagationLossAnalysis.m', option);

outputFile = strcat(parentPath, 'PropagationLossAnalysis.', outputFormat);
renameFile = strcat(parentPath, chip, '_', die, '_', mode, '_', LossDeviceKeyWord, '_', testTimeStamp, '.', outputFormat);
movefile(outputFile, renameFile, 'f');

close all