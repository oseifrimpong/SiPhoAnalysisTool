%function tbChar3_2 (self)
function obj = tbChar3_2 (self)
% shon dec 2014
disp('++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
disp('Running tbChar3_2 analysis script');

%% old style
% Recipe copied for reference
% %<well>,<time(min)>,<reagent>,<ri>,<velocity>,<temp>,<comment>
% 7,60,DIW,1,0,30,degassed
% 7,60,DIW,1,1,30,degassed
% 7,60,DIW,1,10,30,degassed
% 7,60,DIW,1,100,30,degassed

%% new style
% %<well>,<time(min)>,<reagent>,<ri>,<velocity>,<temp>,<comment>
% 7,55,DIW@1ToEquilibriate,1.33,1,30,equilibriate
% 7,55,DIW@0,1.33,0,30,DIW@0uL/min
% 7,55,DIW@1,1,1.33,30,DIW@1uL/min
% 7,55,DIW@10,1.33,10,30,DIW@10uL/min
% 7,55,DIW@100,1.33,100,30,DIW@100uL/min

% need to group data from similar flow regimes
rawPeaks = [];
fitPeaks = [];
rawPeaksGroup = [];   
fitPeaksGroup = [];
chop=10;
% initial flow rate
previousFlowRate = self.dataset{self.appParams.activeChannel, self.firstScanNumber}.params.FlowRate; % sometimes reagents are same but flow rate changes
% initial reagent name
previousReagentName = self.dataset{self.appParams.activeChannel, self.firstScanNumber}.params.ReagentName;

% we want the RMS jitter and (wvl +/- stdev) for each reagent grouping for
% included scans only

for scanNumber = self.firstScanNumber:self.lastScanNumber
    if ~self.dataset{self.appParams.activeChannel, scanNumber}.excludeScan
        % within the same reagent grouping
        if (self.dataset{self.appParams.activeChannel, scanNumber}.params.FlowRate ==...
                previousFlowRate) && strcmpi(previousReagentName,...
                self.dataset{self.appParams.activeChannel, scanNumber}.params.ReagentName)
                
            % build up reagent/flow rate group arrays
            rawPeaks = [rawPeaks self.dataset{self.appParams.activeChannel, scanNumber}.peaks{self.appParams.activePeak}.peakWvl];
            fitPeaks = [fitPeaks self.dataset{self.appParams.activeChannel, scanNumber}.peaks{self.appParams.activePeak}.fitPeakWvl];
        else
            % do calcs
            mr = mean(rawPeaks(chop+1:end-chop));
            raw = rawPeaks(chop+1:end-chop)-mr;
            samples = length(rawPeaks)-2*chop;
            rawRms = rms(raw);
            rawStdev = std(raw);

            mf = mean(fitPeaks(chop+1:end-chop));
            fit = fitPeaks(chop+1:end-chop)-mf;
            fitRms = rms(fit);
            fitStdev = std(fit);
            msg='::::::::::'; disp(msg);            
            msg=strcat('Reagent=', previousReagentName); disp(msg);
            msg=strcat('FlowRate=', num2str(previousFlowRate)); disp(msg);
            msg=strcat('NumSamples=', num2str(samples)); disp(msg);
            msg=strcat('Ch=', num2str(self.appParams.activeChannel)); disp(msg);
            msg=strcat('Pk=', num2str(self.appParams.activePeak)); disp(msg);
            msg=strcat('rawRms_pm=',num2str(rawRms*1e3)); disp(msg);
            msg=strcat('rawStdev_pm=',num2str(rawStdev*1e3)); disp(msg);
            msg=strcat('fitRms_pm=',num2str(fitRms*1e3)); disp(msg);
            msg=strcat('fitStdev_pm=',num2str(fitStdev*1e3)); disp(msg);
                        
            %% for next time            
            % update flow rate and reagent
            previousFlowRate = self.dataset{self.appParams.activeChannel, scanNumber}.params.FlowRate;
            previousReagentName = self.dataset{self.appParams.activeChannel, scanNumber}.params.ReagentName;
            % reset w/in grouping arrays
            rawPeaks = [];
            fitPeaks = [];
            rawPeaks = [rawPeaks self.dataset{self.appParams.activeChannel, scanNumber}.peaks{self.appParams.activePeak}.peakWvl];
            fitPeaks = [fitPeaks self.dataset{self.appParams.activeChannel, scanNumber}.peaks{self.appParams.activePeak}.fitPeakWvl];
        end
    end
end

%% plot the very last set
% do calcs
%mr=mean raw
mr = mean(rawPeaks(chop+1:end-chop));
raw = rawPeaks(chop+1:end-chop)-mr;
samples = length(rawPeaks)-2*chop;
rawRms = rms(raw);
rawStdev = std(raw);

%mf=mean fit
mf = mean(fitPeaks(chop+1:end-chop));
fit = fitPeaks(chop+1:end-chop)-mf;
fitRms = rms(fit);
fitStdev = std(fit);

percentImprovement = (rawRms-fitRms)/rawRms*100;

% report
msg='::::::::::'; disp(msg);
msg=strcat('Reagent=', previousReagentName); disp(msg);
msg=strcat('FlowRate=', num2str(previousFlowRate)); disp(msg);
msg=strcat('NumSamples=', num2str(samples)); disp(msg);
msg=strcat('Ch=', num2str(self.appParams.activeChannel)); disp(msg);
msg=strcat('Pk=', num2str(self.appParams.activePeak)); disp(msg);
msg=strcat('rawRms_pm=',num2str(rawRms*1e3)); disp(msg);
msg=strcat('rawStdev_pm=',num2str(rawStdev*1e3)); disp(msg);
msg=strcat('fitRms_pm=',num2str(fitRms*1e3)); disp(msg);
msg=strcat('fitStdev_pm=',num2str(fitStdev*1e3)); disp(msg);
msg=strcat('percentImprovement=',num2str(percentImprovement)); disp(msg);


% need to return this (even though it doesn't change) so feval call works
% correctly. shon 4 dec 2014
obj = self;
end