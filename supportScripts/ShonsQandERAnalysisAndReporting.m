% Shon 17 May 2014

close all
clear all
clc

rootPath = '\\pandora.bioeng.washington.edu\BioBenchData\IME';
chip = 'A1';
die = '31';
mode = 'TE';
testType = 'SaltSteps';
testTimeStamp = '2014.03.01@14.09';
file = 'Scan160.mat';
includeChannels = [1, 2];
fitting = false;

outputFormat = 'pdf';
parentPath = strcat(rootPath, '\', chip, '\', die, '\');

interestedDevices = {...
    'ThreeRingsCascaded9_RC'};

%% analyze Q's and ER's

% create list of devices to loop through
deviceListStruct = dir(parentPath);
deviceListStruct = deviceListStruct(3:end); % removing . and .. directories
numDevices = length(deviceListStruct);
numChannels = 4;

% initialize storage arrays
D = cell(numDevices, 1); % device info (a struct)
Q = zeros(numDevices, numChannels); % Q's for all channels
ER = zeros(numDevices,numChannels); % ER's for all channels
P = cell(numDevices, 1); % path to results
A = zeros(numDevices, 1); % device analyzed? 1=yes, 0=no

deviceIndex = [];
for ii = 1:length(deviceListStruct)
    thisDevice = deviceListStruct(ii).name;
    dirPath = strcat(parentPath, thisDevice, '\', testType, '\', testTimeStamp, '\');
    if exist(dirPath, 'dir')
        validD = false;
        for iii = 1:length(interestedDevices)
            if ~isempty(strfind(dirPath, interestedDevices{iii}))
                validD = true;
                break;
            end
        end
        if validD
            deviceIndex(end + 1) = ii;
        end
    end
end
numDevices = length(deviceIndex);

for ii = 1:numDevices
    thisDevice = deviceListStruct(deviceIndex(ii)).name;
    dirPath = strcat(parentPath, thisDevice, '\', testType, '\', testTimeStamp, '\');
    filePath = strcat(dirPath, file);
    P{ii} = dirPath; % add path to data directory
    if exist(filePath, 'file')
        % call Q_ER_Estimation function
        %        shons_Q_ER_Estimation(filePath, excludeChannels)
        [Q(ii,1:numChannels), ER(ii,1:numChannels), D{ii}, A(ii,1:numChannels)] = shons_Q_ER_Estimation(filePath, includeChannels, fitting);
    else % try Scan2.mat
        filePath = strcat(dirPath, 'Scan2.mat');
        if exist(filePath, 'file')
            % call Q_ER_Estimation function
            [Q(ii,1:numChannels), ER(ii,1:numChannels), D{ii}, A(ii,1:numChannels)] = shons_Q_ER_Estimation(filePath, includeChannels, fitting);
        else
            fprintf('No %s\\%s\\Scan1.mat or %s\\%s\\Scan2.mat file exists for %s.\n', testType, testTimeStamp, testType, testTimeStamp, thisDevice);
        end
    end
end

    %% write data to excel file
    % first, compile all data into one matrix
    outputArrayFormat = {'<chip>', '<Name>', '<testType>', '<testTimeStamp>', '<detector>', '<Q>', '<ER>', '<dirPath>'};
    outputArray = outputArrayFormat;
    for ii = 1:numDevices % loop through all the devices
        % create a new entry (row) for each detector w/in a device
        %     for jj = 1:length(Q(ii, :))
        %         outputArray(ii, index) = Q(ii,jj); % add other stuff here...
        %         index = index + 1;
        %     end
        
        includeChannel = find(A(ii, :) == 1);
        for jj = includeChannel
            outputArray{end + 1, 1} = chip;
            outputArray{end, 2} = deviceListStruct(deviceIndex(ii)).name;
            outputArray{end, 3} = testType;
            outputArray{end, 4} = testTimeStamp;
            outputArray{end, 5} = jj;
            outputArray{end, 6} = round(Q(ii, jj)*10)/10;
            outputArray{end, 7} = round(ER(ii, jj)*10)/10;
            outputArray{end, 8} = P{ii};
        end
    end
    
    % save the array to an excel file
    %fn = 'C:\Users\vinic_000\Desktop\results.xlsx';
    
    saveFile = 1;
    originalFn = strcat(parentPath,'Q_Analysis_',mode,'_',testType,'_',testTimeStamp);
    fnExtention = '.xlsx';
    completeFn = strcat(originalFn, fnExtention);
    endNum = 0;
    disp('Writing into Excel File...')
    while exist(completeFn, 'file')
        msg = sprintf('File\n\t%s\nalready exist.', completeFn);
        response = questdlg(msg,...
            'Saving File',...
            'Overwrite', 'Append Ending Number', 'Dnn''t save', 'Append Ending Number');
        if strcmp(response, 'Append Ending Number')
            endNum = endNum + 1;
            fn = strcat(originalFn, '_', num2str(endNum));
            completeFn = strcat(fn, fnExtention);
        elseif strcmp(response, 'Overwrite')
            break;
        else
            saveFile = 0;
        end
    end
    if saveFile
        [status, msg] = xlswrite(completeFn, outputArray);
    end
    disp('Done')
    % option = struct(...
    %     'format', outputFormat, ...
    %     'outputDir', parentPath, ...
    %     'showCode', false, ...
    %     'codeToEvaluate', 'shons_Q_ER_Estimation(parentPath, testType, testTimeStamp, file, exculdeChannels)');
    % publish('shons_Q_ER_Estimation.m', option);
    %
    % outputFile = strcat(parentPath, 'shons_Q_ER_Estimation.', outputFormat);
    % renameFile = strcat(parentPath, chip, '_', die, '_', mode, '_', testType, '_', testTimeStamp, '.', outputFormat);
    % movefile(outputFile, renameFile, 'f');
close all