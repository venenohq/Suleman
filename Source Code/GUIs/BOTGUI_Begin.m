global bot_gui_00_vr2o bot_gui_00_objs
vr2o = bot_gui_00_vr2o;
vr2o_bkp = vr2o;
selObjects = bot_gui_00_objs;
axes(handles.axes1);
% BOT (Binary Object Tracker)
%  The other tracker works on a background difference technique. Its called 
% the Binary Object Tracker (BOT). The algorithm takes the first frame of
% the binary image and identifies objects by detecting connected regions. 
% Each connected region is an object. Then it matches the location and size 
% of these objects with the object collection given for tracking. By doing 
% this, it actually tries to map each desired object with a detected object
% approximately sharing it's location and size. It then updates the new
% location of these objects and repeats the process through the rest of the
% video.
%
% See also PHYSTRACK.KLT

    
    watchon;
    vr2o_new = vr2o;
    % some variables to be used in the loop
    lost = false; % used to set a flag that the tracking is lost
    for ii = 1: size(selObjects, 1)
        cx = selObjects(ii, 1) + selObjects(ii, 3) / 2;
        cy = selObjects(ii, 2) + selObjects(ii, 4) / 2;
        eval(['trajectories.tp', num2str(ii), '.x(1) = cx;']);
        eval(['trajectories.tp', num2str(ii), '.y(1) = cy;']);
        eval(['trajectories.tp', num2str(ii), '.xy(1, :) = [cx, cy];']);
        eval(['trajectories.tp', num2str(ii), '.validity(1) = 1;']);
    end
    objs = [];
    for ii = 2:vr2o.TotalFrames
        % temporarily acquire the positions before appending them in the
        % final results
        sObs = [];
        frame = PhysTrack.read2(vr2o, ii, false, false);
        % extract the centroids
        fObs = regionprops(frame, {'centroid', 'BoundingBox'});        
        
        % for each original object, find a probable new object
        for jj = 1:size(selObjects,1)
            lastXY = eval(['trajectories.tp', num2str(jj), '.xy(end,:)']);
            lastSize = selObjects(jj, 3:4);
            for kk = 1:size(fObs,1)   
                thisXY = fObs(kk).Centroid;
                thisSize = fObs(kk).BoundingBox(3:4);
                
                if ...
                        sqrt((lastXY(1) - thisXY(1))^2 + (lastXY(2) - thisXY(2))^2) ...
                        < ...
                        sqrt(thisSize(1)*thisSize(2)) * 5 ...% object matched
                        && ...
                        sqrt(thisSize(1)*thisSize(2)) < ...
                        sqrt(lastSize(1)*lastSize(2)) * 3
                    sObs(end + 1, :) = [fObs(kk).Centroid(:); 1];
                    break;
                end
            end
            
            % check if a match was found for this centroid in the processed
            % frame
            if size(sObs, 1) < jj                
                sObs(end + 1, 1:3) = [lastXY(1), lastXY(2), 0];
                % watchoff;
                % waitfor(msgbox('Tracking process was stopped because one or more of the selected objects were lost.'));
                % lost  = true;
                % break;
            end
        end
        % if lost
        %     break;
        % end
        % store the centroids in the resulting array
        totalValid  = size(sObs,1);
        for jj = 1: size(selObjects, 1)
            eval(['trajectories.tp', num2str(jj), '.x(end + 1) = sObs(jj,1);']);
            eval(['trajectories.tp', num2str(jj), '.y(end + 1) = sObs(jj,2);']);
            eval(['trajectories.tp', num2str(jj), '.xy(end + 1, :) = sObs(jj,1:2);']);
            eval(['trajectories.tp', num2str(jj), '.validity(end + 1) = sObs(jj,3);']);
            
            if sObs(jj, 3) == 0
                totalValid = totalValid - 1;
            end
            col = [0, 255, 255];
            if mean(eval(['trajectories.tp', num2str(jj), '.validity'])) < 1
                col = [255, 0, 0];
            end
            frame = PhysTrack.drawCrossHairMarks(frame, [sObs(jj,1:2), selObjects(jj,3)], col);            
        end
        % preview the progress            
        warning off
        imshow(frame); 
        
        set(handles.progressL, 'String', [num2str(round(double(ii) / double(vr2o.TotalFrames) * 100)), '%']);
        set(handles.progress2L, 'String', ['Total objects: ', num2str(totalValid), '/', num2str(size(sObs,1)),', Processed frame ', num2str(ii), ' of ', num2str(vr2o.TotalFrames)]);
        global bot_trajectories_00  bot_vr2o_new_00
        bot_trajectories_00 = trajectories;
        bot_vr2o_new_00 = vr2o;
    
    end   

