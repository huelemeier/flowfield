% Estimate heading through a world while fixating a point.

clear all;  % clear workspace
addpath('functions') % load in getFrustum function
rng('shuffle'); % Seed the random number generator.

origin_directory = pwd;

% Type in participant id, session number, practice block, etc...
ID = 3;%input('Enter subject ID '); %Input subject ID, this will also be the file name of the output
session = 1;%input('Enter session number '); %Input session number, this will also be the file name of the output
practice = 0;%input('Practice run [1] Experimental run [0] '); %input whether this is a practice run or not

%% set experimental parameters

nframes = 230;  % duration of stimulus (number of frames).
ntrials = 3;    % number of repetitions for each condition
numdots = 8000; % number of dots

d = 20;   % scene depth

show_true_heading = false;




% set up conditions and trial sequence
% first independent variable: whether (1) or not (0) to simulate eye rotation
% second independent variable: horizontal heading directions
independent_variable_sets = {[-20 10 0 10 20]};
[independent_variable_1] = ndgrid(independent_variable_sets{:});
conditions = [independent_variable_1(:)];
trials = repmat(conditions,ntrials,1);
trials = trials(randperm(length(trials)),:);

% define trials of the practice block
if practice
    n = 1;
    trials = repmat(conditions, n, 1); % practice block contains n repetitions of every stimulus combination
    trials = trials(randperm(length(trials)),:);
end


%%

% GL data structure needed for all OpenGL demos:
global GL;

% Is the script running in OpenGL Psychtoolbox? Abort, if not.
AssertOpenGL;

% Restrict KbCheck to checking of ESCAPE key:
KbName('UnifyKeynames');

% open screen and set preference settings
Screen('Preference', 'Verbosity',1);

% Find the screen to use for display:
screenid = max(Screen('Screens'));
stereoMode = 0;
multiSample = 0;

Screen('Preference', 'SkipSyncTests', 1);




%%

% Setup Psychtoolbox for OpenGL 3D rendering support and initialize the
% mogl OpenGL for Matlab wrapper:
InitializeMatlabOpenGL;

PsychImaging('PrepareConfiguration');
% initialize Rift as display
% PsychVRHMD('AutoSetupHMD', 'Monoscopic', 'LowPersistence FastResponse DebugDisplay', [], [], []);
% Open a double-buffered full-screen window on the main displays screen.
%[win, winRect] = PsychImaging('OpenWindow', screenid, 0, [], [], [], stereoMode, multiSample); % second screen
[win, winRect] = PsychImaging('OpenWindow', screenid, 0, [], [], [], stereoMode, multiSample); % debug on one screen
[win_xcenter, win_ycenter] = RectCenter(winRect);
xwidth=RectWidth(winRect);
yheight=RectHeight(winRect);


screen_height=198; %physical height of display in cm
screen_width=248; %physical width of display in cm
screen_distance=100; %physical viewing distance in cm
screen_distance_in_pixels=xwidth/screen_width*screen_distance; %physical viewing distance in pixel

HideCursor;
Priority(MaxPriority(win));

% Setup the OpenGL rendering context of the onscreen window for use by
% OpenGL wrapper. After this command, all following OpenGL commands will
% draw into the onscreen window 'win':
Screen('BeginOpenGL', win);

% Get the aspect ratio of the screen:

% Set viewport properly:
glViewport(0, 0, xwidth, yheight);

% Setup default drawing color to yellow (R,G,B)=(1,1,0). This color only
% gets used when lighting is disabled - if you comment out the call to
% glEnable(GL.LIGHTING).
glColor3f(1,1,0);

% Setup OpenGL local lighting model: The lighting model supported by
% OpenGL is a local Phong model with Gouraud shading.

% Enable the first local light source GL.LIGHT_0. Each OpenGL
% implementation is guaranteed to support at least 8 light sources,
% GL.LIGHT0, ..., GL.LIGHT7
glEnable(GL.LIGHT0);

% Enable alpha-blending for smooth dot drawing:
glEnable(GL.BLEND);
glBlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);

glEnable(GL.DEPTH_TEST);

% Set projection matrix: This defines a perspective projection,
% corresponding to the model of a pin-hole camera - which is a good
% approximation of the human eye and of standard real world cameras --
% well, the best aproximation one can do with 3 lines of code ;-)
glMatrixMode(GL.PROJECTION);
glLoadIdentity;

% Field of view = 89 (suitable for large projection screen). Objects closer than
% 0.1 distance units or farther away than 50 distance units get clipped
% away, aspect ratio is adapted to the monitors aspect ratio:
gluPerspective(89, xwidth/yheight, 0.5, d);


% Setup modelview matrix: This defines the position, orientation and
% looking direction of the virtual camera:
glMatrixMode(GL.MODELVIEW);
glLoadIdentity;

% Our point lightsource is at position (x,y,z) == (1,2,3)...
glLightfv(GL.LIGHT0,GL.POSITION,[ 1 2 3 0 ]);

% Set background clear color to 'black' (R,G,B,A)=(0,0,0,0):
glClearColor(0,0,0,0);

% Clear out the backbuffer: This also cleans the depth-buffer for
% proper occlusion handling: You need to glClear the depth buffer whenever
% you redraw your scene, e.g., in an animation loop. Otherwise occlusion
% handling will screw up in funny ways...
glClear(GL.DEPTH_BUFFER_BIT);

% Finish OpenGL rendering into PTB window. This will switch back to the
% standard 2D drawing functions of Screen and will check for OpenGL errors.

vprt1 = glGetIntegerv(GL.VIEWPORT);
Screen('EndOpenGL', win);

% Show rendered image at next vertical retrace:
Screen('Flip', win);

fps = Screen('FrameRate', win);   % use PTB framerate if its ok.
if fps == 0                       % if PTB framerate does not work, use this
    flip_count = 0;               % rough estimate of the frame rate per second
    timerID=tic;
    while (toc(timerID) < 1)
        Screen('Flip',win);
        flip_count=flip_count+1;
    end
    frame_rate_estimate=flip_count;
    fps = frame_rate_estimate;
end

tspeed = 1.1/fps;  %speed which the observer translates through the environment



%% Welcome screen // start the experiment by clicking the mouse button


% first stuff the observer sees when they start the experiment
[~, ~, buttons1]=GetMouse(screenid);
Screen('TextSize',win, 20);
white = WhiteIndex(win);

while ~any(buttons1)
    Screen('DrawText',win, 'Click the mouse to begin the experiment.',win_xcenter-200,win_ycenter,white);
    Screen('DrawingFinished', win);
    Screen('Flip', win);
    [~, ~, buttons1]=GetMouse(screenid);
end



%% initiate Trial loop

for trial = 1:length(trials)

    % set up conditions for this trial
    heading_deg   = trials(trial,1);

    %generate random dot positions
    [dotsX,dotsY,dotsZ] = CreateUniformDotsIn3DFrustum(numdots,1.2*89,xwidth/yheight,0.5,2*d); %generate dots positions // 89 = fov // 2*d, 1.2 = plane // fixation_point [0, -1,2, -d/2]

    %% set heading stuff
    Screen('BeginOpenGL',win)
    glLoadIdentity
    viewport=glGetIntegerv(GL.VIEWPORT); %viewport
    modelview=glGetDoublev(GL.MODELVIEW_MATRIX); %modelview matrix
    projection=glGetDoublev(GL.PROJECTION_MATRIX); %projection matrix

    heading_vec = [-tand(heading_deg)*d/2, 0, d/2];
    heading_vec = heading_vec/norm(heading_vec);

    translate_observer=[0 0 0]; %start at zero

    % fixation tagrget in cloud
    fixation_point = [0, 0, -d/2]';


    %% view frustum for culling used later

    glPushMatrix
    glLoadIdentity

    %    glRotatef(-heading_deg,0,1,0)

    proj=glGetFloatv(GL.PROJECTION_MATRIX);
    modl=glGetFloatv(GL.MODELVIEW_MATRIX);

    glPopMatrix

    modl=reshape(modl,4,4);
    proj=reshape(proj,4,4);


    Screen('EndOpenGL', win)

    %% Animation loop for a single trial

    for i = 1:nframes;

        % abort program early
        exitkey=KbCheck;
        if exitkey
            clear all
            return
        end

        Screen('BeginOpenGL',win);

        glLoadIdentity

        gluLookAt(translate_observer(1),translate_observer(2),translate_observer(3),fixation_point(1),fixation_point(2),(fixation_point(3)+d)-d,0,1,0); %set camera to look without rotating. normally just use thi

        %% point drawing

        xyzmatrix = [dotsX; dotsY; dotsZ];

        %these variables set up some point drawing
        nrdots=size(xyzmatrix,2);
        nvc=size(xyzmatrix,1);

        glClear(GL.DEPTH_BUFFER_BIT)

        %this bit of code was taken out of the moglDrawDots3D psychtoolbox function which is EXTREMELY inefficient. it is much quicker to just use the relevant openGL function to draw points
        glVertexPointer(nvc, GL.DOUBLE, 0, xyzmatrix);
        glEnableClientState(GL.VERTEX_ARRAY);

        glEnable(GL.POINT_SMOOTH); %enable anti-aliasing
        glHint(GL.POINT_SMOOTH_HINT, GL.DONT_CARE); %but it doesnt need to be that fancy. they are just white dots after all

        glPushMatrix

        glColor3f(0.6,0.6,0.6)
        glPointSize(4)
        glDrawArrays(GL.POINTS, 0, nrdots); %draw the points

        glPopMatrix


        %% show true heading for testing
        if show_true_heading

            heading_point = -d/2 * heading_vec';

            %these variables set up some point drawing
            nrdots=size(heading_point,2);
            nvc=size(heading_point,1);

            glClear(GL.DEPTH_BUFFER_BIT)

            %this bit of code was taken out of the moglDrawDots3D psychtoolbox function which is EXTREMELY inefficient. it is much quicker to just use the relevant openGL function to draw points
            glVertexPointer(nvc, GL.DOUBLE, 0, heading_point);
            glEnableClientState(GL.VERTEX_ARRAY);

            glEnable(GL.POINT_SMOOTH); %enable anti-aliasing
            glHint(GL.POINT_SMOOTH_HINT, GL.DONT_CARE); %but it doesnt need to be that fancy. they are just white dots after all

            glPushMatrix

            glColor3f(0.0,0.0,0.9)
            glPointSize(4)
            glDrawArrays(GL.POINTS, 0, nrdots); %draw the points
            glPopMatrix
        end


        %% draw fixation point
        %these variables set up some point drawing
        nrdots=size(fixation_point,2);
        nvc=size(fixation_point,1);

        glClear(GL.DEPTH_BUFFER_BIT)

        %this bit of code was taken out of the moglDrawDots3D psychtoolbox function which is EXTREMELY inefficient. it is much quicker to just use the relevant openGL function to draw points
        glVertexPointer(nvc, GL.DOUBLE, 0, fixation_point);
        glEnableClientState(GL.VERTEX_ARRAY);

        glEnable(GL.POINT_SMOOTH); %enable anti-aliasing
        glHint(GL.POINT_SMOOTH_HINT, GL.DONT_CARE); %but it doesnt need to be that fancy. they are just white dots after all

        glPushMatrix

        glColor3f(0.0,0.9,0.0)
        glPointSize(8)
        glDrawArrays(GL.POINTS, 0, nrdots); %draw the points
        glPopMatrix


        Screen('EndOpenGL',win);


        translate_observer=translate_observer-tspeed.*heading_vec; % update translated position
        heading_vec;
        heading_deg;

        Screen('Flip', win);

    end    %end animation loop


    Screen('BeginOpenGL',win)
    glMatrixMode(GL.MODELVIEW)
    glLoadIdentity

    Screen('EndOpenGL',win)


    %% wait for user response

    % this loop redraws the static final frame and waits for a user response
    buttons = 0;
    while ~buttons

        [mx, ~, buttons]=GetMouse(screenid);

        % redraw dotss

        Screen('BeginOpenGL',win);

        glMatrixMode(GL.MODELVIEW)
        glLoadIdentity
        glClear(GL.DEPTH_BUFFER_BIT)

        % set camera looking position and location
        gluLookAt(translate_observer(1),translate_observer(2),translate_observer(3),fixation_point(1),fixation_point(2),(fixation_point(3)+d)-d,0,1,0); %set camera to look without rotating. normally just use thi


        xyzmatrix = [dotsX; dotsY; dotsZ];

        %these variables set up some point drawing
        nrdots=size(xyzmatrix,2);
        nvc=size(xyzmatrix,1);

        glClear(GL.DEPTH_BUFFER_BIT)

        %this bit of code was taken out of the moglDrawDots3D psychtoolbox function which is EXTREMELY inefficient. it is much quicker to just use the relevant openGL function to draw points
        glVertexPointer(nvc, GL.DOUBLE, 0, xyzmatrix);
        glEnableClientState(GL.VERTEX_ARRAY);

        glEnable(GL.POINT_SMOOTH); %enable anti-aliasing
        glHint(GL.POINT_SMOOTH_HINT, GL.DONT_CARE); %but it doesnt need to be that fancy. they are just white dots after all

        glPushMatrix

        glColor3f(0.6,0.6,0.6)
        glPointSize(4)
        glDrawArrays(GL.POINTS, 0, nrdots); %draw the points

        glPopMatrix



        % show true heading for testing if needed
        if show_true_heading
            heading_point = -d/2 * heading_vec';

            %these variables set up some point drawing
            nrdots=size(heading_point,2);
            nvc=size(heading_point,1);

            glClear(GL.DEPTH_BUFFER_BIT)

            %this bit of code was taken out of the moglDrawDots3D psychtoolbox function which is EXTREMELY inefficient. it is much quicker to just use the relevant openGL function to draw points
            glVertexPointer(nvc, GL.DOUBLE, 0, heading_point);
            glEnableClientState(GL.VERTEX_ARRAY);

            glEnable(GL.POINT_SMOOTH); %enable anti-aliasing
            glHint(GL.POINT_SMOOTH_HINT, GL.DONT_CARE); %but it doesnt need to be that fancy. they are just white dots after all

            glPushMatrix

            glColor3f(0.0,0.0,0.9)
            glPointSize(6)
            glDrawArrays(GL.POINTS, 0, nrdots); %draw the points
            glPopMatrix
        end

        % show response cursor
        response_cursor = [(mx-win_xcenter)/xwidth*20,0,-d/2]';

        %these variables set up some point drawing
        nrdots=size(response_cursor,2);
        nvc=size(response_cursor,1);

        glClear(GL.DEPTH_BUFFER_BIT)

        %this bit of code was taken out of the moglDrawDots3D psychtoolbox function which is EXTREMELY inefficient. it is much quicker to just use the relevant openGL function to draw points
        glVertexPointer(nvc, GL.DOUBLE, 0, response_cursor);
        glEnableClientState(GL.VERTEX_ARRAY);

        glEnable(GL.POINT_SMOOTH); %enable anti-aliasing
        glHint(GL.POINT_SMOOTH_HINT, GL.DONT_CARE); %but it doesnt need to be that fancy. they are just white dots after all

        glPushMatrix

        glColor3f(0.9,0.0,0.0)
        glPointSize(7)
        glDrawArrays(GL.POINTS, 0, nrdots); %draw the points
        glPopMatrix

        Screen('EndOpenGL',win);

        response = -atand(response_cursor(1)/response_cursor(3));

        Screen('Flip', win);

    end

    Screen('Flip',win);
    WaitSecs(0.5);


    %% create output file

    % output variables
    output(trial,1) = ID;
    output(trial,2) = session;
    output(trial,3) = trial;
    output(trial,4) = heading_deg;
    output(trial,5) = response;

    % save output variables as text-document and rename the file
    if ~practice

        cd('data');
        dlmwrite([num2str(ID), '_',num2str(session), '_heading.txt'],output,'\t');
        cd(origin_directory)

    end


end % end of the trial loop

%% Done. Close screen and exit
Screen('CloseAll');
