% Vince Wu 04/05/2014
% Analysis Information

close all
clear all
clc

rootPath = '\\pandora.bioeng.washington.edu\BioBenchData\EB\';
chip = '436Q2L';
die = 'A';
mode = 'TE';
testType = 'WetTest';
testTimeStamp = '2014.04.25@14.43';
file = 'Scan1.mat';
exculdeChannels = [3, 4];

outputFormat = 'pdf';
parentPath = strcat(rootPath, '\', chip, '\', die, '\');

option = struct(...
    'format', outputFormat, ...
    'outputDir', parentPath, ...
    'showCode', false, ...
    'codeToEvaluate', 'TestResultReporting(parentPath, testType, testTimeStamp, file, exculdeChannels)');
publish('TestResultReporting.m', option);

outputFile = strcat(parentPath, 'TestResultReporting.', outputFormat);
renameFile = strcat(parentPath, chip, '_', die, '_', mode, '_', testType, '_', testTimeStamp, '.', outputFormat);
movefile(outputFile, renameFile, 'f');

close all