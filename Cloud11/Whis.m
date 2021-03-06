%% Socket setup

% imagename = 'image-210.jpg';
% imagedir = strcat('C:\Users\Hari\Documents\UAV\Image-Recognition\Cloud10\images_final\', imagename);
% img = imread(imagedir);

prevId = 0;


stdMessageLength = 100;

javaaddpath(pwd);
import decoder.*

%% Main Loop
while true
    try
        serverMsg = urlread('http://192.168.0.13:25005/api/images?processed=false&limit=1', 'Timeout', .5);
        struct = loadjson(serverMsg);
        struct = struct{1,1};
    catch
        fprintf("Waiting for unproccesed images! " + string(prevId) + " Processed So Far\n");
        pause(1);
        continue;
    end
    %% After message is read
    if struct.x0x5F_id == prevId
        fprintf("Waiting for unproccesed images! " + string(prevId) + " Processed So Far\n");
        pause(1);
        continue;
    end
    try
    t = tcpip('localhost', 9999);
    fopen(t);
    
    prevId = 0;
    catch
        continue
    end

    
    prevId = struct.x0x5F_id;
    encoded = java.lang.String(struct.data_warped);
    fname = pwd + "/inter/temp" + struct.x0x5F_id + ".jpg";
    decoder.decodeAndSave(encoded, fname);
    
    img = imread(char(fname));
    %% Debugging
%     img = imread('C:\Users\Hari\Documents\UAV\Image-Recognition\tf\tf_files\inter\temp1.jpg');
%     struct.lat = 1;
%     struct.lon = 1;
%     struct.x0x5F_id = 1;
    
    %% PRE-IMAGE PROCESSING
    imgGray = rgb2gray(img);
    
    initThresh = .3;
    
    %BWimgMask = edge(interEdges,'canny', .3);
    BWimgMask = edge(imgGray,'canny', initThresh);
    
    % Used to fill small holes/discontinuities
    se10 = strel('square', 10);
    se5 = strel('square', 5);
    
    % thisImageThick is used to determine the boundary of a blob after dilating to fill holes (not displayed though)
    thisImageThick = imdilate(BWimgMask,se5);
    
    
    blobs = regionprops(thisImageThick, 'BoundingBox');
    
    strongThresh = initThresh + .1;
    while length(blobs) > 10
        BWimgMask = edge(imgGray,'canny', strongThresh);
        thisImageThick = imdilate(BWimgMask,se5);
        blobs = regionprops(thisImageThick, 'BoundingBox');
        strongThresh = strongThresh + .1;
    end
    
    % noiseLVL = 1;
    % while length(blobs) > 5
    %     thisImageThick = bwareaopen(thisImageThick, 20*noiseLVL);
    %     noiseLVL = noiseLVL + 1;
    %     blobs = regionprops(thisImageThick, 'BoundingBox');
    % end
    
    serverdata = "dir " + pwd + "/inter/" + " " + string(length(blobs) + " " + string(struct.x0x5F_id) + " " + string(struct.lat) + " " + string(struct.lon));
    fwrite(t, stdMessage(serverdata, stdMessageLength));
    fprintf("Connected to Vados\n");
    
    z = 1;
    
    %% LOOPING THROUGH BLOBS
    while z <= length(blobs)
        boundary = blobs(z).BoundingBox;
        
        % Crop it out of the original gray scale image.
        % thisBlob = imcrop(BWimg, boundary + [-3 -3 6 6]);
        boundary = boundary + [-10 -10 20 20];
        thisBlob = imcrop(img, boundary);
        
        z = z + 1;
        
        %         figure
        %         hold on
        %         imshow(thisBlob)
        
        if max(size(thisBlob) >= 1000)
            fwrite(t, "ignore");
            continue;
        end
        
        %     if numberOfWhite < 80
        %         z = z + 1;
        %         continue;
        %     end
        
        %    [height, width] = size(thisBlob);
        %imshow(thisBlob);
        %     thisBlob = bwareaopen(thisBlob, 50);
        %thisBlob = imdilate(thisBlob,se2);
        
        strBoundary = string(boundary);
        serverdata = strcat("blob ", "temp" + struct.x0x5F_id + ".jpg", " ", strBoundary(1), " ", strBoundary(2), " ", strBoundary(3), " ", strBoundary(4));
        fwrite(t, stdMessage(serverdata, stdMessageLength));
        
        %     close all
        fprintf('Processed a blob\n')
        %     shape = py.pyZeno.get_targets(imagedir, boundary);
        %
        %
        %     shape = char(shape);
        %     figure
        %     imshow(thisBlob)
        %     if(strcmp(shape, 'Unknown'))
        %         close;
        %     else
        %         title(shape);
        %     end
        
    end
    
    fprintf('Done!')
    
end


