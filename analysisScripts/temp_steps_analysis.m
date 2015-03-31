%function temp_steps_analysis (self)
function obj = temp_steps_analysis (self)
% jonasf jan 2015
disp('++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
disp('Running temp steps analysis');

% <well>,<time(min)>,<reagent>,<ri>,<flow rate>,<temp>,<comment>
% 4,5,TEC20C,1.3341,10,20,comment1
% 4,5,TEC25C,1.3341,10,25,comment1
% 4,5,TEC30C,1.3341,10,30,comment1
% 4,5,TEC35C,1.3341,10,35,comment1
% 4,10,TEC20C,1.3341,10,20,comment1

% params:
%     laserParams
%     detectorParams
%     opticalStageParams
%     TECParms
%     PumpParams
%     SweepParams
%     AssayParams
%     CurrentWell
%     ReagentName
%     ReagentRI
%     StageTemp
%     FlowRate
%     BioAssayQuickNote


% need to group data from same temp
rawPeaks = [];
fitPeaks = [];
chop=1;  %Exclude number of scan at beginning and end;
% initial Temp
%assumes only temperature in degrees
previousTemp = round(str2num(self.dataset{self.appParams.activeChannel, self.firstScanNumber}.params.StageTemp)); % sometimes reagents are same but flow rate changes
% initial reagent name
previousReagentName = self.dataset{self.appParams.activeChannel, self.firstScanNumber}.params.ReagentName;

step_counter = 1; 
% included scans only

for scanNumber = self.firstScanNumber:self.lastScanNumber
    if ~self.dataset{self.appParams.activeChannel, scanNumber}.excludeScan
        % within the same reagent grouping
        if (round(str2num(self.dataset{self.appParams.activeChannel, scanNumber}.params.StageTemp)) ==...
                previousTemp) && strcmpi(previousReagentName,...
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

            %vector for plotting
            mr_p(step_counter)=mr;
            rawStdev_p(step_counter)=rawStdev;
            mf_p(step_counter) = mf;
            fitStdev_p(step_counter)=fitStdev;
            temp(step_counter) = previousTemp; 
            
            step_counter=step_counter +1;
            
            msg='::::::::::'; disp(msg);            
            msg=strcat('Reagent=', previousReagentName); disp(msg);
            msg=strcat('Temperature=', num2str(previousTemp)); disp(msg);
            msg=strcat('NumSamples=', num2str(samples)); disp(msg);
            msg=strcat('Ch=', num2str(self.appParams.activeChannel)); disp(msg);
            msg=strcat('Pk=', num2str(self.appParams.activePeak)); disp(msg);
            msg=strcat('rawRms_pm=',num2str(rawRms*1e3)); disp(msg);
            msg=strcat('rawStdev_pm=',num2str(rawStdev*1e3)); disp(msg);
            msg=strcat('fitRms_pm=',num2str(fitRms*1e3)); disp(msg);
            msg=strcat('fitStdev_pm=',num2str(fitStdev*1e3)); disp(msg);
                        
            %% for next time            
            % update flow rate and reagent
            previousTemp = round(str2num(self.dataset{self.appParams.activeChannel, scanNumber}.params.StageTemp));
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

%vector for plotting
mr_p(step_counter)=mr;
rawStdev_p(step_counter)=rawStdev;
mf_p(step_counter) = mf;
fitStdev_p(step_counter)=fitStdev;
temp(step_counter) = previousTemp; 
percentImprovement = (rawRms-fitRms)/rawRms*100;

% report
msg='::::::::::'; disp(msg);
msg=strcat('Reagent=', previousReagentName); disp(msg);
msg=strcat('StageTemp=', num2str(previousTemp)); disp(msg);
msg=strcat('NumSamples=', num2str(samples)); disp(msg);
msg=strcat('Ch=', num2str(self.appParams.activeChannel)); disp(msg);
msg=strcat('Pk=', num2str(self.appParams.activePeak)); disp(msg);
msg=strcat('rawRms_pm=',num2str(rawRms*1e3)); disp(msg);
msg=strcat('rawStdev_pm=',num2str(rawStdev*1e3)); disp(msg);
msg=strcat('fitRms_pm=',num2str(fitRms*1e3)); disp(msg);
msg=strcat('fitStdev_pm=',num2str(fitStdev*1e3)); disp(msg);
msg=strcat('percentImprovement=',num2str(percentImprovement)); disp(msg);


p = polyfit(temp,mf_p,1); %linear fit 
f = polyval(p,[min(temp)-1:1:max(temp)+1]); 
figure; hold on;
errorbar(temp, mf_p, fitStdev_p, 'or',...
    'MarkerSize', 10); 
plot([min(temp)-1:1:max(temp)+1],f,...
    'LineWidth',2);
xlabel('Temperature [^oC]'); 
ylabel('Peak Wavelength [nm]'); 
title(strcat('Thermal Sensitivity: ',num2str(round( p(1)*1000) ), 'pm/^oC')); 

msg='::::::::::'; disp(msg);
msg=strcat('Thermal Sensitivity = ', num2str(round( p(1)*1000) ), 'pm/^oC'); 

% need to return this (even though it doesn't change) so feval call works
% correctly. shon 4 dec 2014
obj = self;
end