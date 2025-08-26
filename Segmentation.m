function [segmented_chars, binary_plate] = carplate_segmentation(image_path)
% FIXED CAR PLATE CHARACTER SEGMENTATION
% Resolved morphological operations that were destroying character structure
% Handles both dark-on-light and light-on-dark plates with gentle processing

    % Helper function
    function result = iif(condition, true_val, false_val)
        if condition
            result = true_val;
        else
            result = false_val;
        end
    end

    % Handle input image path
    if nargin < 1 || isempty(image_path)
        image_path = 'plate_1.png'; % SET YOUR IMAGE PATH HERE
        
        if ~exist(image_path, 'file')
            fprintf('Manual path not found. Please select an image file.\n');
            [filename, pathname] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp', 'Image files'}, 'Select car plate image');
            if filename == 0, error('No file selected'); end
            image_path = fullfile(pathname, filename);
        end
    end
    
    if ~exist(image_path, 'file')
        error('Image file not found: %s', image_path);
    end
    
    % Load original image
    original_img = imread(image_path);
    figure('Name', 'Fixed Car Plate Segmentation', 'Position', [100, 100, 1400, 900]);
    
    subplot(3, 4, 1);
    imshow(original_img);
    title('Original Plate Image');
    
    % Convert to grayscale
    if size(original_img, 3) == 3
        gray_img = rgb2gray(original_img);
    else
        gray_img = original_img;
    end
    
    subplot(3, 4, 2);
    imshow(gray_img);
    title('Grayscale Image');
    
    % GENTLE preprocessing - preserve character structure
    filtered_img = medfilt2(gray_img, [2 2]); % Very light median filtering
    
    subplot(3, 4, 3);
    imshow(filtered_img);
    title('Lightly Filtered');
    
    % Moderate contrast enhancement
    enhanced_img = adapthisteq(filtered_img, 'ClipLimit', 0.01, 'NumTiles', [8 8]);
    
    subplot(3, 4, 4);
    imshow(enhanced_img);
    title('Contrast Enhanced');
    
    % Smart thresholding - try multiple methods
    % Method 1: Adaptive with bright characters
    binary1 = imbinarize(enhanced_img, 'adaptive', 'Sensitivity', 0.4, 'ForegroundPolarity', 'bright');
    
    % Method 2: Adaptive with dark characters  
    binary2 = imbinarize(enhanced_img, 'adaptive', 'Sensitivity', 0.4, 'ForegroundPolarity', 'dark');
    
    % Method 3: Global Otsu
    binary3 = imbinarize(enhanced_img);
    
    % Method 4: Inverted Otsu
    binary4 = ~imbinarize(enhanced_img);
    
    subplot(3, 4, 5);
    montage({binary1, binary2, binary3, binary4}, 'Size', [2 2]);
    title('Different Thresholding Methods');
    
    % SMART POLARITY DETECTION
    % Analyze image characteristics to choose best binarization
    [h, w] = size(enhanced_img);
    center_region = enhanced_img(round(h*0.2):round(h*0.8), round(w*0.1):round(w*0.9));
    center_mean = mean(center_region(:));
    overall_mean = mean(enhanced_img(:));
    
    % Test which binary gives better connected components in expected character size range
    candidates = {binary1, binary2, binary3, binary4};
    candidate_names = {'Adaptive-Bright', 'Adaptive-Dark', 'Otsu', 'Inverted-Otsu'};
    scores = zeros(1, 4);
    
    for i = 1:4
        % Quick analysis of connected components
        cc = bwconncomp(candidates{i});
        stats_temp = regionprops(cc, 'Area', 'BoundingBox');
        
        valid_count = 0;
        for j = 1:length(stats_temp)
            area = stats_temp(j).Area;
            bbox = stats_temp(j).BoundingBox;
            char_height = bbox(4);
            char_width = bbox(3);
            
            % Check if component looks like a character
            if area > 50 && area < h*w*0.15 && char_height > h*0.15 && ...
               char_height < h*0.85 && char_width > 5 && char_width < w*0.25
                valid_count = valid_count + 1;
            end
        end
        scores(i) = valid_count;
    end
    
    % Choose the method with most valid character-like components
    [~, best_idx] = max(scores);
    binary_plate = candidates{best_idx};
    
    fprintf('Selected thresholding method: %s (found %d potential characters)\n', ...
            candidate_names{best_idx}, scores(best_idx));
    
    subplot(3, 4, 6);
    imshow(binary_plate);
    title(sprintf('Smart Selection: %s', candidate_names{best_idx}));
    
    % VERY GENTLE morphological operations - only if absolutely necessary
    % Check if characters are broken and need minimal repair
    cc_before = bwconncomp(binary_plate);
    
    % Only apply minimal morphological operations if we have too many small fragments
    if cc_before.NumObjects > 15
        % Only close very small gaps (1-2 pixels)
        se_tiny = strel('disk', 1);
        binary_plate = imclose(binary_plate, se_tiny);
        
        % Remove only very tiny noise specks
        binary_plate = bwareaopen(binary_plate, 15);
    end
    
    % Alternative: if characters are merged, try opening
    cc_after = bwconncomp(binary_plate);
    if cc_after.NumObjects < 4 % Expecting at least 4-6 characters typically
        se_small = strel('disk', 1);
        binary_plate_opened = imopen(binary_plate, se_small);
        cc_opened = bwconncomp(binary_plate_opened);
        
        % Only use opened version if it gives more reasonable number of components
        if cc_opened.NumObjects > cc_after.NumObjects && cc_opened.NumObjects < 12
            binary_plate = binary_plate_opened;
        end
    end
    
    subplot(3, 4, 7);
    imshow(binary_plate);
    title('Gently Processed');
    
    % Find connected components
    [labeled_img, num_objects] = bwlabel(binary_plate, 8);
    stats = regionprops(labeled_img, 'BoundingBox', 'Area', 'Extent', 'Solidity', 'Eccentricity');
    
    % REFINED character filtering
    valid_chars = [];
    
    % Adaptive thresholds based on image size
    img_height = size(binary_plate, 1);
    img_width = size(binary_plate, 2);
    
    min_area = max(30, img_height * img_width * 0.002);
    max_area = img_height * img_width * 0.2;
    min_height = img_height * 0.1;
    max_height = img_height * 0.9;
    min_width = 3;
    max_width = img_width * 0.3;
    
    fprintf('\n=== FILTERING CRITERIA ===\n');
    fprintf('Image size: %dx%d\n', img_height, img_width);
    fprintf('Area range: %d - %d\n', round(min_area), round(max_area));
    fprintf('Height range: %.1f - %.1f\n', min_height, max_height);
    
    for i = 1:num_objects
        area = stats(i).Area;
        bbox = stats(i).BoundingBox;
        width = bbox(3);
        height = bbox(4);
        aspect_ratio = width / height;
        extent = stats(i).Extent;
        solidity = stats(i).Solidity;
        
        % More flexible criteria
        is_valid = area >= min_area && area <= max_area && ...
                  height >= min_height && height <= max_height && ...
                  width >= min_width && width <= max_width && ...
                  aspect_ratio >= 0.1 && aspect_ratio <= 3.0 && ...
                  extent >= 0.15 && solidity >= 0.2;
        
        if is_valid
            valid_chars = [valid_chars, i];
        end
    end
    
    % Sort characters from left to right
    if ~isempty(valid_chars)
        char_centers = [];
        for i = 1:length(valid_chars)
            bbox = stats(valid_chars(i)).BoundingBox;
            char_centers = [char_centers, bbox(1) + bbox(3)/2];
        end
        [~, sort_idx] = sort(char_centers);
        valid_chars = valid_chars(sort_idx);
    end
    
    % Extract characters from ORIGINAL GRAYSCALE IMAGE (not binary)
    % This preserves intensity information needed for OCR
    segmented_chars = {};
    subplot(3, 4, 8);
    imshow(binary_plate);
    title('Detected Characters');
    hold on;
    
    for i = 1:length(valid_chars)
        bbox = stats(valid_chars(i)).BoundingBox;
        x = round(bbox(1));
        y = round(bbox(2));
        width = round(bbox(3));
        height = round(bbox(4));
        
        % Minimal padding
        padding = 2;
        x1 = max(1, x - padding);
        y1 = max(1, y - padding);
        x2 = min(size(enhanced_img, 2), x + width + padding);
        y2 = min(size(enhanced_img, 1), y + height + padding);
        
        % Extract character from ENHANCED GRAYSCALE IMAGE (not binary)
        % This preserves intensity gradients and details needed for OCR
        char_img = enhanced_img(y1:y2, x1:x2);
        
        % Resize to standard size with proper interpolation for grayscale
        char_img_resized = imresize(char_img, [64, 48], 'bilinear');
        
        segmented_chars{i} = char_img_resized;
        
        % Draw bounding box
        rectangle('Position', [x, y, width, height], 'EdgeColor', 'g', 'LineWidth', 2);
        text(x, y-5, sprintf('%d', i), 'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold');
    end
    hold off;
    
    % Display results - showing GRAYSCALE character images
    if ~isempty(segmented_chars)
        subplot(3, 4, 9);
        % Create montage of grayscale characters
        montage_img = [];
        separator = ones(64, 3) * 128; % Gray separator instead of white
        
        for i = 1:length(segmented_chars)
            if i == 1
                montage_img = segmented_chars{i};
            else
                montage_img = [montage_img, separator, segmented_chars{i}];
            end
        end
        
        if ~isempty(montage_img)
            imshow(montage_img, []);
        end
        title(sprintf('Segmented Characters - Grayscale (%d found)', length(segmented_chars)));
        
        % Show individual grayscale characters
        subplot(3, 4, 10);
        if length(segmented_chars) >= 1
            imshow(segmented_chars{1}, []);
            title('First Character (Grayscale)');
        end
        
        subplot(3, 4, 11);
        if length(segmented_chars) >= 2
            imshow(segmented_chars{2}, []);
            title('Second Character (Grayscale)');
        end
        
        subplot(3, 4, 12);
        if length(segmented_chars) >= 3
            imshow(segmented_chars{3}, []);
            title('Third Character (Grayscale)');
        end
    else
        subplot(3, 4, 9);
        text(0.5, 0.5, 'No characters detected', 'HorizontalAlignment', 'center');
        title('No Characters Found');
    end
    
    % Analysis output
    fprintf('\n=== ANALYSIS RESULTS ===\n');
    fprintf('Total objects found: %d\n', num_objects);
    fprintf('Valid characters detected: %d\n', length(segmented_chars));
    
    % Detailed analysis
    fprintf('\n=== DETAILED ANALYSIS ===\n');
    for i = 1:min(num_objects, 10)
        area = stats(i).Area;
        bbox = stats(i).BoundingBox;
        width = bbox(3);
        height = bbox(4);
        aspect_ratio = width / height;
        extent = stats(i).Extent;
        solidity = stats(i).Solidity;
        
        is_valid = ismember(i, valid_chars);
        
        fprintf('Obj %2d: A=%4d, W=%5.1f, H=%5.1f, AR=%4.2f, Ext=%4.2f, Sol=%4.2f %s\n', ...
                i, round(area), width, height, aspect_ratio, extent, solidity, ...
                iif(is_valid, '[VALID]', '[rejected]'));
    end
    
    % Save results
    [pathstr, name, ~] = fileparts(image_path);
    if isempty(pathstr), pathstr = pwd; end
    
    output_dir = fullfile(pathstr, [name '_fixed_characters']);
    if ~exist(output_dir, 'dir'), mkdir(output_dir); end
    
    fprintf('\n=== SAVING RESULTS ===\n');
    fprintf('Output directory: %s\n', output_dir);
    
    imwrite(binary_plate, fullfile(output_dir, 'binary_plate.png'));
    
    % Save grayscale character images (suitable for OCR)
    for i = 1:length(segmented_chars)
        filename = fullfile(output_dir, sprintf('char_%02d.png', i));
        % Save as grayscale image with proper intensity scaling
        imwrite(segmented_chars{i}, filename);
        fprintf('Saved: char_%02d.png (grayscale, %dx%d)\n', i, size(segmented_chars{i}, 1), size(segmented_chars{i}, 2));
    end
    
    fprintf('\nSegmentation completed successfully!\n');
end

%% MAIN EXECUTION SCRIPT
clear; clc; close all;

fprintf('Fixed Car Plate Character Segmentation\n');
fprintf('======================================\n');

try
    % Set your image path here
    manual_image_path = 'your_carplate_image.png'; % CHANGE THIS PATH
    
    if exist('manual_image_path', 'var') && ~isempty(manual_image_path) && exist(manual_image_path, 'file')
        fprintf('Using manual image path: %s\n', manual_image_path);
        [chars, binary_img] = carplate_segmentation(manual_image_path);
    else
        fprintf('Manual path not found. Using file dialog...\n');
        [chars, binary_img] = carplate_segmentation();
    end
    
    fprintf('\n=== FINAL RESULTS ===\n');
    fprintf('Number of characters detected: %d\n', length(chars));
    
    if ~isempty(chars)
        fprintf('Character size: %dx%d pixels (grayscale for OCR)\n', size(chars{1}, 1), size(chars{1}, 2));
        fprintf('Characters saved as grayscale images suitable for OCR.\n');
    end
    
catch ME
    fprintf('Error: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Line: %d\n', ME.stack(1).line);
    end
end