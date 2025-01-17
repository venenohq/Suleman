PhysTrack.Wizard.MarkSectionStart('Open File');
% Create a video reader object. 
vro = PhysTrack.VideoReader2(true, false, 240);

% generate the time stamps
t = PhysTrack.GenerateTimeStamps(vro);
PhysTrack.Wizard.MarkSectionStart('Define a Coordinate System');
% we need a static coordinate system to be placed on carom board. The
% orientation doesn't matter for the analysis but its better to leave it as
% it is. It weill help relateing the objects in the video to the objects in
% the plots.
% The coordinate system is stored in rwRCS and the pixels per meter
% constant in ppm.
questdlg('Define a reference coordinate system.', '', 'OK', 'OK');
[rwRCS, ppm] = PhysTrack.DrawCoordinateSystem(vro);

PhysTrack.Wizard.MarkSectionStart('Mark Objects');
% let the user select the object needed to be tracked.
% the user will first identify 2 markers on the object going to collide in
% the other (Object A) and then two points on Object B.
obs = PhysTrack.GetObjects(vro);

PhysTrack.Wizard.MarkSectionStart('Track marked objects');
% call the automatic object tracker now and give it the video and the
% objects from the first frame. It will track these objects throughout the
% video.
% trPt_ will contain the trajectories
% vro on the left of equal sign is used to sync it with the vro being
% returned from the tracker because the out frame might change during the
% tracking process.
[trajs, vro] = PhysTrack.KLT(vro, obs);

PhysTrack.Wizard.MarkSectionStart('Draw circles and process');
% We will stitch two circles with the trajectories to visualize the pucks
% themselves. Acquire the circles using PhysTrack function.
% cenA, cenB are center coordinates, radA, radB are radii.
[cenA, radA, cenB, radB] = PhysTrack.Get2Circles(vro);

% Up to this points, we are dealing with the untranformed coordinates and
% pixel units. every thing is compatible with each other. so, no special
% care has to be taken.

% stitch the circles with the trajectories. Now, a circle doesn't have any
% corners. Instead, we use the center and one random point right on the
% perphery to keep it's track of translation and rotation.


PhysTrack.Wizard.MarkSectionStart('Process All');
%these objA, objB now contain the trajectories of the center and a
%periphereal point on each circle. These trajectories are different than
%the track marker's trajectories.
objA = PhysTrack.StitchObjectToPoints([cenA; [cenA(1), cenA(2) + radA]], trajs.tp1, trajs.tp2);
objB = PhysTrack.StitchObjectToPoints([cenB; [cenB(1), cenB(2) + radB]], trajs.tp3, trajs.tp4);

% transform the both traectories and convert the units to meters
objA = PhysTrack.TransformCart2Cart(objA, rwRCS);
objB = PhysTrack.TransformCart2Cart(objB, rwRCS);
objA = PhysTrack.StructOp(objA, ppm, './');
objB = PhysTrack.StructOp(objB, ppm, './');

% also, convert the units of radii. We might need it in next steps.
radA = radA / ppm; 
radB = radB / ppm;

% also, convert the original trajtory of the track pointers
trajectories = PhysTrack.TransformCart2Cart(trajs, rwRCS);
trajectories = PhysTrack.StructOp(trajectories, ppm, './');

% make index guess for IoC

% now we need to identify the index of collision. so that we can divide the
% trajectories in two parts.
% so we calculate the distance between the center of pucks and find out the
% frame in which it is minimum. 
% Store the dist in minDist and index in IoC
IoC = 0; minDist = inf;
for ii = 1:length(t)  
    dist = PhysTrack.DistanceBetween(objA.tp1.xy(ii, :), objB.tp1.xy(ii, :));
    if dist < minDist
        minDist = dist;
        IoC = ii;
    end
end
% for both parts of motion of each object, create a fit which fits the data
% in straight lines. (y = mx + c)
% to divide the trajectories, we now use IoC
objAfit1 = PhysTrack.lsqCFit(objA.tp1.x(1:IoC - 1), objA.tp1.y(1:IoC - 1),'y', 'm*x+c', 'x');
objAfit2 = PhysTrack.lsqCFit(objA.tp1.x(IoC:end),   objA.tp1.y(IoC:end),'y', 'm*x+c', 'x');
% no need to get this fit. coz it is illogical
% objBfit1 = lsqFun3(objB.tp1.x(1:IoC - 1), objB.tp1.y(1:IoC - 1),'y', 'm*x+c', 'x');
objBfit2 = PhysTrack.lsqCFit(objB.tp1.x(IoC:end),   objB.tp1.y(IoC:end),'y', 'm*x+c', 'x');
    
% get angular displacement of both objects
dAngA = PhysTrack.GetAngDispFrom2DtrackPoints(objA.tp1, objA.tp2);
dAngB = PhysTrack.GetAngDispFrom2DtrackPoints(objB.tp1, objB.tp2);

% get linear displacement of both objects (final - first)
dLinA = sqrt((objA.tp1.x - objA.tp1.x(1)).^2 + (objA.tp1.y - objA.tp1.y(1)).^2);
dLinB = sqrt((objB.tp1.x - objB.tp1.x(1)).^2 + (objB.tp1.y - objB.tp1.y(1)).^2);

%calculate displacement of obj 1 at the 4 points (start, before collision, after collision, end)
%first, get x and y displacements
% first get the components.
objAd1x = objA.tp1.x(1:IoC-1)- objA.tp1.x(1);
objAd1y = objA.tp1.y(1:IoC-1)- objA.tp1.y(1);
%make disp = 0 just after collision
% negate first point from final to convert distance into displacement.
objAd2x = objA.tp1.x(IoC:end)- objA.tp1.x(IoC);
objAd2y = objA.tp1.y(IoC:end)- objA.tp1.y(IoC);
% combine the components
objAd1 = sqrt(objAd1x.^2 + objAd1y.^2);
objAd2 = sqrt(objAd2x.^2 + objAd2y.^2);

%similary, trim the time stamps for usability
%trim Time Stamps
objAt1 = t(1:IoC - 1);
objAt2 = t(IoC:end);

% now, lerts get the velocities from the displacements
%get velocity
[objAtv1, objAv1] = PhysTrack.deriv(objAt1,objAd1,1);
[objAtv2, objAv2] = PhysTrack.deriv(objAt2,objAd2,1);

% now that we have the velocities, we need to fit them in some model to
% calculate the actual time of collision.
%fit the velocities in simple model with constant friction
objAv1Fit = PhysTrack.lsqCFit(objAtv1,objAv1,'v', 'vi + a * t', 't');
objAv2Fit = PhysTrack.lsqCFit(objAtv2,objAv2,'v', 'vi + a * t', 't');

%get velocities from fit for the 4 events.
% Its like using f(x).... put x (time), get y (v). coz the curve fit model
% was designed this way.
objAvi = objAv1Fit(t(1));
objAvbc = objAv1Fit(t(IoC -1));
objAvac = objAv2Fit(t(IoC));
objAvf = objAv2Fit(t(end));

% repeat the procedure for the object B. Skip the part before collision coz
% the body was at rest.
%calculate velocities of obj 2 at the 2 points
%first, get x and y displacements
objBdx = objB.tp1.x(IoC:end)- objB.tp1.x(IoC);
objBdy = objB.tp1.y(IoC:end)- objB.tp1.y(IoC);
%get displacements
objBd = sqrt(objBdx.^2 + objBdy.^2);
%trim Time Stamps
objBt = t(IoC:end);
%get velocity
[objBtv, objBv]  = PhysTrack.deriv(objBt,objBd,1);
%fit the velocities
objBvFit = PhysTrack.lsqCFit(objBtv,objBv,'v', 'vi + a * t', 't');
%get velocities from fit for the 2 events
objBvi = objBvFit(objBtv(1));
objBvf = objBvFit(objBtv(end));


% lets start displaying the data now.
figHandle = figure;
whitebg([1,1,1]);
set(figHandle, 'Position', [200, 200, 800, 800]);
%raw preview
hold on;
plot(objA.tp1.x,objA.tp1.y, '+', 'Color',[0.5,0.1,0.1]);
viscircles(objA.tp1.xy(1, :), radA , 'LineWidth', 1, 'EdgeColor', 'red');
viscircles(objA.tp1.xy(IoC, :), radA , 'LineWidth', 1, 'EdgeColor', 'red', 'LineStyle' , '-.');
viscircles(objA.tp1.xy(end, :), radA , 'LineWidth', 1, 'EdgeColor', 'red', 'LineStyle' , '--');

plot(objB.tp1.x,objB.tp1.y, '+','Color',[0.5,0.5,0.5])
viscircles(objB.tp1.xy(IoC, :), radB , 'LineWidth', 1, 'EdgeColor', 'blue');
viscircles(objB.tp1.xy(end, :), radB , 'LineWidth', 1, 'EdgeColor', 'blue', 'LineStyle' , '--');

legend('Obj 1 Track', 'Obj 2 at Track')
title ('Positins and tracks of objects as captured from video');
xlabel('x-Coordinates (meters)')
ylabel('y-Coordinates (meters)')

axis equal

figHandle = figure;
set(figHandle, 'Position', [200, 200, 800, 800]);
%raw preview
hold on;
plot(trajectories.tp1.x,trajectories.tp1.y, '-', 'Color', PhysTrack.GetColor('Maroon')/255);
plot(trajectories.tp2.x,trajectories.tp2.y, '-', 'Color', PhysTrack.GetColor('DarkGreen')/255);
plot(trajectories.tp3.x,trajectories.tp3.y, '-', 'Color', PhysTrack.GetColor('Maroon')/255);
plot(trajectories.tp4.x,trajectories.tp4.y, '-', 'Color', PhysTrack.GetColor('DarkGreen')/255);
viscircles(objA.tp1.xy(1,:), radA , 'LineWidth', 1, 'EdgeColor', 'red');
viscircles(objA.tp1.xy(IoC, :), radA , 'LineWidth', 1, 'EdgeColor', 'red', 'LineStyle' , '-.');
viscircles(objA.tp1.xy(end, :), radA , 'LineWidth', 1, 'EdgeColor', 'red', 'LineStyle' , '--');

title ('Trajectories of original tracked points');
xlabel('x-Coordinates (meters)')
ylabel('y-Coordinates (meters)')

viscircles(objB.tp1.xy(IoC, :), radA , 'LineWidth', 1, 'EdgeColor', 'red', 'LineStyle' , '-.');
viscircles(objB.tp1.xy(end, :), radA , 'LineWidth', 1, 'EdgeColor', 'red', 'LineStyle' , '--');

whitebg([0,0,0])
axis equal

%obj 1
%initial before col
objAI1 = objA.tp1.xy(1, :);
%final before col
objAF1 = objA.tp1.xy(IoC + 1, :);
%final w/o col expected
objAFe1 = objA.tp1.xy(end, :);
%initial after col
objAI2 = objA.tp1.xy(IoC + 1, :);
%final after col
objAF2 = objA.tp1.xy(end, :);

objBI = objB.tp1.xy(IoC, :);
objBF = objB.tp1.xy(end, :);

% Now, we are going to find out the intersection point of the lines of
% object A before and after collision.
% isx is intersection point's X
% this is simple x coordinate from two lines in y = mx+ c form.
isx = (objAfit1.c - objBfit2.c)/(objBfit2.m - objAfit1.m);
% isy is intersection point's Y. obtain it from fit and x.
isy = objAfit1(isx);

% we now also calculate the important points
% calucate the coordinates of object at the four points using
% the fit results from above. 
objAI1(2) = objAfit1(objAI1(1));
objAF1(2) = objAfit1(objAF1(1));
objAI2(2) = objAfit2(objAI2(1));
objAF2(2) = objAfit2(objAF2(1));
objAFe1(2) = objAfit1(objAFe1(1));
objBI(2) = objBfit2(objBI(1));
objBF(2) = objBfit2(objBF(1));

% lets start plotting
figHandle = figure;
set(figHandle, 'Position', [200, 200, 800, 800]);
hold on;

plot([objAI1(1),objAF1(1)], [objAI1(2),objAF1(2)], 'Color', [0,1,0.5]);
plot([objAI2(1),objAF2(1)], [objAI2(2),objAF2(2)], 'b');
plot([objBI(1),objBF(1)], [objBI(2),objBF(2)],'r');
thet1 = PhysTrack.angleDimDraw(objAI2, objAfit2.m, objAfit1.m, 0.3, [1,0,1]);
thet2 = PhysTrack.angleDimDraw([isx,isy], objAfit1.m, objBfit2.m, 0.3, [1,1,0]);
legend(...
    strcat('Object 1 before Collision; v_i = ', num2str(objAvi), ';v_f = ', num2str(objAvbc)), ...
    strcat('Object 1 after Collision; v_i = ', num2str(objAvac), ';v_f = ', num2str(objAvf)), ...
    strcat('Object 2 after Collision; v_i = ', num2str(objBvi), ';v_f = ', num2str(objBvf)), ...
    strcat('\theta_1 = ', num2str(thet1)), ...
    strcat('\theta_2 = ', num2str(thet2)))
plot([objAF1(1),objAFe1(1)], [objAF1(2),objAFe1(2)],'--' ,'Color', [0,1,0.5]);
plot([isx, objBI(1)], [isy, objBI(2)],'--' ,'Color', [1,0,0]);
viscircles([objAI1(1),objAI1(2)], radA, 'LineWidth', 1, 'EdgeColor', 'red');
viscircles([objAF1(1),objAF1(2)], radA, 'LineWidth', 1, 'EdgeColor', 'red', 'LineStyle' , '-.');
viscircles([objAF2(1),objAF2(2)], radA, 'LineWidth', 1, 'EdgeColor', 'red', 'LineStyle' , '--');
viscircles([objBI(1),objBI(2)], radB, 'LineWidth', 1, 'EdgeColor', 'blue', 'LineStyle' , '-.');
viscircles([objBF(1),objBF(2)], radB, 'LineWidth', 1, 'EdgeColor', 'blue', 'LineStyle' , '--');

whitebg([0,0,0])
axis equal
PhysTrack.cascade;


% lets leave some important findings in the workspace as well.
cenA = objA.tp1.xy;
ppA = objA.tp2.xy;
cenB = objB.tp1.xy;
ppB = objB.tp2.xy;

% temp variables
clear isx isy mn mnx mny mx mxx mxy objAd1 objAd1x objAd1y objAd2 objAd2x objAd2y objBd objBdx objBdy 
clear kd kdx kdy ans answer defaultValues dlg_title figHandle lastValidFID num_lines options prompt 

% result variables
clear objAF1 objAF2 objAFe1 objAfit1 objAfit2 objAI1 objAI2 objAt1 objAt2 objAtv1 objAtv2 objAv1 objAv1Fit objAv2 objAv2Fit trPt_ trPt
clear objAvac objAvbc objAvf objAvi objBF objBfit1 objBfit2 objBI objBt objBtv objBv objBvf objBvFit objBvi thet1 thet2
