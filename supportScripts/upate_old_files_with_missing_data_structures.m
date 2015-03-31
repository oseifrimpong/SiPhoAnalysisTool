% dirList = {...
%     '2014.02.24@11.49',...
%     '2014.02.24@12.18',...
%     '2014.02.24@12.42',...
%     '2014.02.24@23.24',...
%     '2014.02.25@13.23'};

dirList = {...
    'E:\jonas_dopbox\Dropbox (MLP)\BioBenchData\IME_A1_27_GC1_TBCharacterization\2015.02.26@16.47'};

arrayIndex = 0;
paramsA = {};
peakResultsA = {};
scanResultsA = {};

for ii = 1:length(dirList)
    str = strcat(dirList{ii},'\','Scan*.mat');
    fileList = dir(str);
    scan_num_offset = 0; 
    %need to figure out if what the first scan is (if other than scan1.mat
    for jj = 1:length(fileList)
       fileName = strcat(dirList{ii},'\','Scan',num2str(jj),'.mat'); 
       if exist(fileName,'file'); 
           break; 
       else
           scan_num_offset = jj; 
       end
    end
    
    
    %% read in the files
    for jj = 1:length(fileList)
       % make filename
       fileName = strcat(dirList{ii},'\','Scan',num2str(jj+scan_num_offset),'.mat');
       scanFileData=load(fileName);
       disp(fileName);
       
       %% create new structures for forward compatability
       %% jonasf : added for testbench data analysis
       params = scanFileData.params;
       if ~isfield(scanFileData.params, 'ReagentNmae')
           params.ReagentName = 'Air';
       end
       if ~isfield(scanFileData.params, 'FlowRate')
           params.FlowRate = '0';
       end
       scanFileData = rmfield(scanFileData, 'params');
       save(fileName, 'params', '-append');
       if scan_num_offset >0
           newfileName = strcat(dirList{ii},'\','Scan',num2str(jj),'.mat');
           movefile(fileName, newfileName); 
       end
         
    end
end