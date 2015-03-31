function plot_3DHeatMap_grating_coupler
close all; 
clear all; 

%EBeam TE data
%load('C:\Users\Jonas\Dropbox\pandora_copy\TestbenchCharacterization_EB_448Q4L_A\PowerHeatMapTest\2014.12.04@12.33\PowerHeatMapTest.mat'); 

%IME A1 chip 27 data
% TE
% load('C:\Users\Jonas\Dropbox\pandora_copy\TestbenchCharacterization_IME_A1_27\PowerHeatMapTest\2014.12.02@16.21\PowerHeatMapTest.mat');
% TE
% load('C:\Users\Jonas\Dropbox\pandora_copy\TestbenchCharacterization_IME_A1_27\PowerHeatMapTest\2014.12.03@10.07\PowerHeatMapTest.mat');
% TM
 load('C:\Users\Jonas\Dropbox\pandora_copy\TestbenchCharacterization_IME_A1_27\PowerHeatMapTest\2014.12.03@21.47\PowerHeatMapTest.mat');

%loads data created by PowerHeatMapTest.m for testbench characterization

detector = 1; 

%MotorPos
%PowerValues <4D double>
%Temperature <26x14x11 double>
%xDistance <1x26>
%yDistance <1x14>
%zDistance <1x11>

%Define slices to plot
sx = [];
sy = [];
sz = [10, 60, 120,180];
%surface(xDistance, yDistance, PowerValues(:, :, 1, 1)');

%plot cross section at single height
isolines = [-15,-30,-50];
figure; 

hold on;
surface(yDistance,xDistance,PowerValues(:,:,1,detector));
%shading interp
xlabel('x in [\mum]');
ylabel('y in [\mum]'); 
[C,b]=contour(yDistance,xDistance,PowerValues(:,:,1,detector),isolines);
text_handle = clabel(C,b);
text_prop=get(text_handle,'FontWeight')
set(text_handle,'FontWeight','bold',...
    'FontSize', 12);
%     'BackgroundColor',[1 1 .6],...
%     'Edgecolor',[.7 .7 .7])


set(b ,'LineWidth',3);
set(b, 'EdgeColor', [0 0 0]); 
set(b, 'ShowText','on');
hold off;

figure;
hold on;
slice(yDistance,xDistance,zDistance,PowerValues(:,:,:,detector),sy,sx,sz);
xlabel('y in [\mu m]');
ylabel('x in [\mu m]');
zlabel('z in [\mu m]');
%shading interp;
%a=contourslice(yDistance,xDistance,zDistance,PowerValues(:,:,:,detector),sy,sx,sz,[-40 -25 -15 -10]);
hold off

set(a ,'LineWidth',2);
properties = get(a)
set(a, 'EdgeColor', [0 0 0]); 

end