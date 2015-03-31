% Vince Wu 04/07/2014
% Analysis Information

close all
clear all
clc

rootPath = '\\pandora.bioeng.washington.edu\BioBenchData\EB\';
chip = '436Q2L';
die = 'A';
mode = 'TM';
testType = 'WetTest';
testTimeStamp = '2014.04.24@17.30';
file = 'Scan2.mat';
checkChannel = 1;
exculdeChannels = [3, 4];

outputFormat = 'pdf';
parentPath = strcat(rootPath, '\', chip, '\', die, '\');

option = struct(...
    'format', outputFormat, ...
    'outputDir', parentPath, ...
    'showCode', false, ...
    'codeToEvaluate', 'BraggGratingAnalysis(parentPath, testType, testTimeStamp, mode, file, checkChannel, exculdeChannels)');
publish('BraggGratingAnalysis.m', option);

outputFile = strcat(parentPath, 'BraggGratingAnalysis.', outputFormat);
renameFile = strcat(parentPath, chip, '_', die, '_', mode, '_BraggAnalysis_', testType, sprintf('_Detector%d_', checkChannel), testTimeStamp, '.', outputFormat);
movefile(outputFile, renameFile, 'f');

close all