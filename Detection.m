function plates = detectLicensePlate(imagePath)
    % Main function to detect license plates in an image
    % Input: imagePath - path to the input image
    
    try
        % Read the image
        img = imread(imagePath);
        figure('Name', 'License Plate Detection', 'NumberTitle', 'off');
        
        % Display original image
        subplot(2, 3, 1);
        imshow(img);
        title('Original Image');
        
        % Convert to grayscale if needed
        if size(img, 3) == 3
            grayImg = rgb2gray(img);
        else
            grayImg = img;
        end
        
        % Preprocessing
        processedImg = preprocessImage(grayImg);
        subplot(2, 3, 2);
        imshow(processedImg);
        title('Preprocessed Image');
        
        % Edge detection
        edges = detectEdges(processedImg);
        subplot(2, 3, 3);
        imshow(edges);
        title('Edge Detection');
        
        % Morphological operations
        morphImg = morphologicalProcessing(edges);
        subplot(2, 3, 4);
        imshow(morphImg);
        title('Morphological Processing');
        
        % Find potential license plate regions
        candidates = findPlateCandidates(morphImg, grayImg);
        subplot(2, 3, 5);
        imshow(img);
        title('Candidate Regions');
        hold on;
        drawBoundingBoxes(candidates, 'yellow', 1, 'Candidate');
        hold off;
        
        % Validate and extract license plates
        plates = validatePlates(candidates, grayImg);
        
        % Display results with bounding boxes
        subplot(2, 3, 6);
        imshow(img);
        title('Detected License Plates');
        hold on;
        drawBoundingBoxes(plates, 'red', 3, 'Plate');
        hold off;
        
        % Create a separate figure for final results
        figure('Name', 'Final Detection Results', 'NumberTitle', 'off');
        imshow(img);
        title('License Plate Detection Results');
        hold on;
        drawBoundingBoxes(plates, 'red', 3, 'License Plate');
        hold off;
        
        if ~isempty(plates)
            fprintf('Found %d potential license plate(s)\n', length(plates));
            
            % Extract and display individual plates
            for i = 1:length(plates)
                figure('Name', sprintf('License Plate %d', i), 'NumberTitle', 'off');
                plateRegion = imcrop(img, plates(i).BoundingBox);
                imshow(plateRegion);
                title(sprintf('Extracted Plate %d - Size: %.0fx%.0f', i, ...
                    plates(i).BoundingBox(3), plates(i).BoundingBox(4)));
            % Save the cropped plate as an image file
                filename = sprintf('plate_%d.png', i);  % e.g. plate_1.png, plate_2.png
                imwrite(plateRegion, filename);

            end
        else
            fprintf('No license plates detected\n');
            plates = []; % Return empty array if no plates found
        end
        
    catch ME
        fprintf('Error: %s\n', ME.message);
        plates = []; % Return empty array on error
    end
end

function processedImg = preprocessImage(grayImg)
    % Preprocessing steps to enhance the image
    
    % Apply Gaussian filter to reduce noise
    processedImg = imgaussfilt(grayImg, 1);
    
    % Histogram equalization for better contrast
    processedImg = adapthisteq(processedImg);
    
    % Optional: Apply median filter to reduce salt and pepper noise
    processedImg = medfilt2(processedImg, [3 3]);
end

function edges = detectEdges(img)
    % Detect edges using Sobel operator
    
    % Apply Sobel edge detection
    edges = edge(img, 'sobel');
    
    % Alternative: Try Canny edge detection
    % edges = edge(img, 'canny', [0.1 0.2]);
    
    % Clean up small noise
    edges = bwareaopen(edges, 50);
end

function morphImg = morphologicalProcessing(edges)
    % Apply morphological operations to connect characters
    
    % Create structuring elements
    se_rect = strel('rectangle', [3, 15]); % Horizontal connection
    se_close = strel('rectangle', [5, 5]);  % General closing
    
    % Dilate to connect nearby edges (characters)
    morphImg = imdilate(edges, se_rect);
    
    % Close gaps
    morphImg = imclose(morphImg, se_close);
    
    % Fill holes
    morphImg = imfill(morphImg, 'holes');
    
    % Remove small objects
    morphImg = bwareaopen(morphImg, 500);
end

function candidates = findPlateCandidates(binaryImg, originalImg)
    % Find potential license plate regions based on geometric properties
    % Optimized for Malaysian license plates
    
    % Get connected components
    cc = bwconncomp(binaryImg);
    stats = regionprops(cc, 'BoundingBox', 'Area', 'Extent', 'Solidity');
    
    % Initialize candidates as empty struct array with proper fields
    candidates = struct('BoundingBox', {}, 'Area', {}, 'Extent', {}, 'Solidity', {});
    candidateIdx = 1;
    
    fprintf('Analyzing %d connected components...\n', length(stats));
    
    for i = 1:length(stats)
        bbox = stats(i).BoundingBox;
        width = bbox(3);
        height = bbox(4);
        area = stats(i).Area;
        extent = stats(i).Extent;
        solidity = stats(i).Solidity;
        
        % Malaysian license plate aspect ratio consideration
        % Standard plates: ~3:1, Some plates can be wider: ~4:1 to 5:1
        aspectRatio = width / height;
        
        % More lenient criteria for Malaysian plates
        if (aspectRatio >= 1.8 && aspectRatio <= 7.0) && ...  % Wider range for Malaysian plates
           (area >= 800 && area <= 60000) && ...              % Slightly larger area range
           (extent >= 0.25) && ...                            % More lenient extent
           (solidity >= 0.25) && ...                          % More lenient solidity
           (width >= 60 && height >= 15)                      % Smaller minimum size
            
            % Properly assign struct to struct array
            candidates(candidateIdx).BoundingBox = stats(i).BoundingBox;
            candidates(candidateIdx).Area = stats(i).Area;
            candidates(candidateIdx).Extent = stats(i).Extent;
            candidates(candidateIdx).Solidity = stats(i).Solidity;
            
            fprintf('  Candidate %d: AR=%.2f, Area=%.0f, W=%.0f, H=%.0f\n', ...
                candidateIdx, aspectRatio, area, width, height);
            
            candidateIdx = candidateIdx + 1;
        end
    end
    
    if isempty(candidates)
        fprintf('No suitable candidates found\n');
    else
        fprintf('Found %d candidates\n', length(candidates));
    end
end

function validPlates = validatePlates(candidates, grayImg)
    % Validate candidates using additional criteria
    
    % Initialize as empty struct array with proper fields
    validPlates = struct('BoundingBox', {}, 'Area', {}, 'Extent', {}, 'Solidity', {});
    validIdx = 1;
    
    if isempty(candidates)
        return;
    end
    
    for i = 1:length(candidates)
        bbox = candidates(i).BoundingBox;
        
        % Extract the region
        plateRegion = imcrop(grayImg, bbox);
        
        % Additional validation using character-like features
        if validatePlateContent(plateRegion)
            % Properly assign struct fields
            validPlates(validIdx).BoundingBox = candidates(i).BoundingBox;
            validPlates(validIdx).Area = candidates(i).Area;
            validPlates(validIdx).Extent = candidates(i).Extent;
            validPlates(validIdx).Solidity = candidates(i).Solidity;
            validIdx = validIdx + 1;
        end
    end
    
    fprintf('Validated %d plates from %d candidates\n', length(validPlates), length(candidates));
end

function isValid = validatePlateContent(plateRegion)
    isValid = false;
    try
        % Otsu + inverted
        level = graythresh(plateRegion);
        plateBW1 = imbinarize(plateRegion, level);
        plateBW2 = ~plateBW1;
        
        methods = {plateBW1, plateBW2};
        bestMethod = 1; bestCharCount = 0;
        
        for m = 1:length(methods)
            cc = bwconncomp(methods{m});
            numChars = cc.NumObjects;
            if numChars >= 3 && numChars <= 15 && numChars > bestCharCount
                bestCharCount = numChars;
                bestMethod = m;
            end
        end
        
        plateBW = methods{bestMethod};
        cc = bwconncomp(plateBW);
        numChars = cc.NumObjects;
        
        % If too few or too many objects → reject
        if numChars < 2 || numChars > 15
            return;
        end
        
        % Analyze characters
        charStats = regionprops(cc, 'BoundingBox', 'Area', 'Extent', 'Solidity', 'Centroid');
        validChars = 0;
        totalArea = size(plateRegion,1) * size(plateRegion,2);
        yCoords = [];
        
        for j = 1:length(charStats)
            bbox = charStats(j).BoundingBox;
            ar = bbox(4) / bbox(3); % aspect ratio
            a = charStats(j).Area;
            if (ar >= 0.2 && ar <= 6.0) && ...
               (a >= 10 && a <= totalArea*0.6)
                validChars = validChars + 1;
                yCoords(end+1) = charStats(j).Centroid(2); %#ok<AGROW>
            end
        end
        
        % Check alignment
        if ~isempty(yCoords) && std(yCoords) < size(plateRegion,1)*0.3 && validChars >= 2
            isValid = true;
        end
    catch
        % Be lenient if error
        isValid = true;
    end
end


% Helper function with enhanced bounding box display
function testDetectorWithVisualization()
    % Enhanced example usage function with better visualization
    fprintf('=== License Plate Detector with Bounding Boxes ===\n');
    fprintf('Usage:\n');
    fprintf('  detectLicensePlate(''path/to/your/image.jpg'');           %% Display only\n');
    fprintf('  plates = detectLicensePlate(''path/to/your/image.jpg'');  %% Get results\n');
    fprintf('Features:\n');
    fprintf('  - Yellow boxes: Candidate regions\n');
    fprintf('  - Red boxes: Validated license plates\n');
    fprintf('  - Text labels with region information\n');
    fprintf('Make sure your image contains vehicles with visible license plates\n\n');
    
    % You can uncomment and modify the following line to test with your image
    % plates = detectLicensePlate('sample_car_image.jpg');
    
    % Example of saving results
    % if ~isempty(plates)
    %     img = imread('sample_car_image.jpg');
    %     saveDetectionResults(img, plates, 'detection_results.png');
    % end
end

% Additional utility function for drawing bounding boxes
function drawBoundingBoxes(regions, color, lineWidth, label)
    % Draw bounding boxes around detected regions
    % Inputs:
    %   regions - array of region properties with BoundingBox field
    %   color - color of the bounding box ('red', 'yellow', etc.)
    %   lineWidth - thickness of the bounding box lines
    %   label - text label to display near the box
    
    if isempty(regions)
        return;
    end
    
    for i = 1:length(regions)
        bbox = regions(i).BoundingBox;
        
        % Draw rectangle
        rectangle('Position', bbox, 'EdgeColor', color, 'LineWidth', lineWidth);
        
        % Add text label
        if nargin >= 4 && ~isempty(label)
            text(bbox(1), bbox(2) - 5, sprintf('%s %d', label, i), ...
                'Color', color, 'FontSize', 10, 'FontWeight', 'bold', ...
                'BackgroundColor', 'white', 'EdgeColor', color);
        end
        
        % Display confidence info
        if isfield(regions, 'Area')
            confidenceText = sprintf('Area: %.0f', regions(i).Area);
            text(bbox(1), bbox(2) + bbox(4) + 15, confidenceText, ...
                'Color', color, 'FontSize', 8, 'BackgroundColor', 'white');
        end
    end
end

% Enhanced function to save detection results
function saveDetectionResults(img, plates, outputPath)
    % Save the image with bounding boxes drawn
    % Inputs:
    %   img - original image
    %   plates - detected license plate regions
    %   outputPath - path to save the result image
    
    figure('Visible', 'off'); % Create invisible figure
    imshow(img);
    hold on;
    drawBoundingBoxes(plates, 'red', 3, 'Plate');
    hold off;
    
    % Save the figure
    saveas(gcf, outputPath);
    close(gcf);
    
    fprintf('Detection results saved to: %s\n', outputPath);
end
function batchDetection(imageFolder)
    % Process multiple images in a folder
    
    % Get all image files
    imageFiles = dir(fullfile(imageFolder, '*.jpg'));
    imageFiles = [imageFiles; dir(fullfile(imageFolder, '*.png'))];
    imageFiles = [imageFiles; dir(fullfile(imageFolder, '*.jpeg'))];
    
    fprintf('Processing %d images...\n', length(imageFiles));
    
    for i = 1:length(imageFiles)
        imagePath = fullfile(imageFolder, imageFiles(i).name);
        fprintf('Processing: %s\n', imageFiles(i).name);
        
        try
            detectLicensePlate(imagePath);
        catch ME
            fprintf('Error processing %s: %s\n', imageFiles(i).name, ME.message);
        end
    end
end

plates = detectLicensePlate('Test_image12.jpg');

% Then you can work with the results
if ~isempty(plates)
    fprintf('Number of plates detected: %d\n', length(plates));
    for i = 1:length(plates)
        bbox = plates(i).BoundingBox;
        fprintf('Plate %d: Position [%.0f, %.0f], Size [%.0f x %.0f]\n', ...
                i, bbox(1), bbox(2), bbox(3), bbox(4));
    end
end