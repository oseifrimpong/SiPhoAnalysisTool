function varargout = guiMarking(varargin)
%GUIMARKING M-file for guiMarking.fig
%      GUIMARKING, by itself, creates a new GUIMARKING or raises the existing
%      singleton*.
%
%      H = GUIMARKING returns the handle to a new GUIMARKING or the handle to
%      the existing singleton*.
%
%      GUIMARKING('Property','Value',...) creates a new GUIMARKING using the
%      given property value pairs. Unrecognized properties are passed via
%      varargin to guiMarking_OpeningFcn.  This calling syntax produces a
%      warning when there is an existing singleton*.
%
%      GUIMARKING('CALLBACK') and GUIMARKING('CALLBACK',hObject,...) call the
%      local function named CALLBACK in GUIMARKING.M with the given input
%      arguments.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help guiMarking

% Last Modified by GUIDE v2.5 06-Jan-2015 09:28:06

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @guiMarking_OpeningFcn, ...
                   'gui_OutputFcn',  @guiMarking_OutputFcn, ...
                   'gui_LayoutFcn',  [], ...
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


% --- Executes just before guiMarking is made visible.
function guiMarking_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

% Choose default command line output for guiMarking
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes guiMarking wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = guiMarking_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function peakTrackingFigCropUB_Callback(hObject, eventdata, handles)
% hObject    handle to peakTrackingFigCropUB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of peakTrackingFigCropUB as text
%        str2double(get(hObject,'String')) returns contents of peakTrackingFigCropUB as a double


% --- Executes during object creation, after setting all properties.
function peakTrackingFigCropUB_CreateFcn(hObject, eventdata, handles)
% hObject    handle to peakTrackingFigCropUB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function peakTrackingFigCropLB_Callback(hObject, eventdata, handles)
% hObject    handle to peakTrackingFigCropLB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of peakTrackingFigCropLB as text
%        str2double(get(hObject,'String')) returns contents of peakTrackingFigCropLB as a double


% --- Executes during object creation, after setting all properties.
function peakTrackingFigCropLB_CreateFcn(hObject, eventdata, handles)
% hObject    handle to peakTrackingFigCropLB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
