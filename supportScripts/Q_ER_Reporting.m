function Q_ER_Reporting(dirList)

%% Plot all Q and ER information
for l = 1:length(dirList)
    filePath = dirList{l};
    % look for detector1... , detector2..., etc.
    filePathWildTerm = strcat(filePath,'\','Detector*.mat'); % only need .mat files
    detectorFileList = ls(filePathWildTerm);
    % loop through the number of detector files that exist
    for ii = 1:length(detectorFileList)
        fn = strcat(filePath,'\',detectorFileList(ii,:));
        fh = figure;
        open(fn);
        set(fh, 'Units', 'Normalized', 'Position', [.20, .30, .60, .40])
    end
end