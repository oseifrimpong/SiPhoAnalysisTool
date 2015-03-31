function varargout = peakFittingGUI(varargin)
% PEAKFITTINGGUI MATLAB code for peakFittingGUI.fig
%      PEAKFITTINGGUI, by itself, creates a new PEAKFITTINGGUI or raises the existing
%      singleton*.
%
%      H = PEAKFITTINGGUI returns the handle to a new PEAKFITTINGGUI or the handle to
%      the existing singleton*.
%
%      PEAKFITTINGGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PEAKFITTINGGUI.M with the given input arguments.
%
%      PEAKFITTINGGUI('Property','Value',...) creates a new PEAKFITTINGGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before peakFittingGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to peakFittingGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help peakFittingGUI

% Last Modified by GUIDE v2.5 22-Nov-2014 21:07:02

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @peakFittingGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @peakFittingGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before peakFittingGUI is made visible.
function peakFittingGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to peakFittingGUI (see VARARGIN)

% Choose default command line output for peakFittingGUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% This sets up the initial plot - only do when we are invisible
% so window can get raised using peakFittingGUI.
if strcmp(get(hObject,'Visible'),'off')
    plot(rand(5));
end

% UIWAIT makes peakFittingGUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = peakFittingGUI_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
