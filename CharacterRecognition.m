% OCR DIAGNOSTIC AND ALTERNATIVE RECOGNITION METHODS
% This will help identify why OCR is failing and provide alternatives

function recognizedText = diagnose_and_recognize(chars)
    recognizedText = '';
    
    fprintf('=== OCR DIAGNOSTIC ANALYSIS ===\n');
    
    % Create figure to visualize processing steps
    figure('Name', 'OCR Diagnostic', 'Position', [100, 100, 1600, 800]);
    
    for i = 1:min(7, length(chars))
        fprintf('\n--- DIAGNOSTIC CHARACTER %d ---\n', i);
        
        char_img = chars{i};
        
        % Step 1: Original character
        subplot(4, 7, i);
        imshow(char_img);
        title(sprintf('Original %d', i));
        
        % Step 2: Convert to uint8 and invert
        char_uint8 = uint8(char_img) * 255;
        char_inverted = 255 - char_uint8;
        
        subplot(4, 7, i + 7);
        imshow(char_inverted);
        title(sprintf('Inverted %d', i));
        
        % Step 3: Clean up the character
        % Remove very small noise
        char_cleaned = bwareaopen(char_inverted < 128, 5);
        char_cleaned = uint8(~char_cleaned) * 255;
        
        subplot(4, 7, i + 14);
        imshow(char_cleaned);
        title(sprintf('Cleaned %d', i));
        
        % Step 4: Heavy preprocessing for OCR
        char_padded = padarray(char_cleaned, [40, 40], 255, 'both');
        char_huge = imresize(char_padded, 12, 'bilinear'); % Very large scaling
        
        % Apply morphological operations to improve shape
        se = strel('disk', 2);
        char_morph = imclose(char_huge < 128, se);
        char_morph = imopen(char_morph, se);
        char_final = uint8(~char_morph) * 255;
        
        % Additional sharpening
        char_final = imsharpen(char_final);
        
        subplot(4, 7, i + 21);
        imshow(char_final);
        title(sprintf('OCR Ready %d', i));
        
        fprintf('Original size: %dx%d\n', size(char_img));
        fprintf('Final size: %dx%d\n', size(char_final));
        fprintf('White pixels: %d/%d (%.1f%%)\n', ...
            sum(char_final(:) > 200), numel(char_final), ...
            100*sum(char_final(:) > 200)/numel(char_final));
        
        % Try OCR on heavily processed image
        ocr_char = '?';
        try
            % Save the processed image temporarily to check manually
            temp_filename = sprintf('temp_char_%d.png', i);
            imwrite(char_final, temp_filename);
            
            % Multiple OCR attempts with different settings
            ocr_results = {};
            
            % Method 1: Default OCR
            result1 = ocr(char_final);
            if ~isempty(result1.Text)
                ocr_results{end+1} = strtrim(result1.Text);
            end
            
            % Method 2: With character set
            result2 = ocr(char_final, 'CharacterSet', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ');
            if ~isempty(result2.Text)
                ocr_results{end+1} = strtrim(result2.Text);
            end
            
            % Method 3: Numbers only
            result3 = ocr(char_final, 'CharacterSet', '0123456789');
            if ~isempty(result3.Text)
                ocr_results{end+1} = strtrim(result3.Text);
            end
            
            % Method 4: Letters only
            result4 = ocr(char_final, 'CharacterSet', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
            if ~isempty(result4.Text)
                ocr_results{end+1} = strtrim(result4.Text);
            end
            
            fprintf('OCR attempts: ');
            for j = 1:length(ocr_results)
                fprintf('"%s" ', ocr_results{j});
            end
            fprintf('\n');
            
            % Choose best result
            if ~isempty(ocr_results)
                ocr_char = ocr_results{1}(1);
            end
            
            % Clean up temp file
            delete(temp_filename);
            
        catch ME
            fprintf('OCR Error: %s\n', ME.message);
        end
        
        % ALTERNATIVE METHOD 1: Template Matching
        template_char = simple_template_match(char_img);
        
        % ALTERNATIVE METHOD 2: Feature-based recognition
        feature_char = feature_based_recognition(char_img);
        
        fprintf('OCR result: "%s"\n', ocr_char);
        fprintf('Template match: "%s"\n', template_char);
        fprintf('Feature-based: "%s"\n', feature_char);
        
        % Choose best result (voting or priority)
        if ocr_char ~= '?'
            final_char = ocr_char;
        elseif template_char ~= '?'
            final_char = template_char;
        else
            final_char = feature_char;
        end
        
        recognizedText = [recognizedText, final_char];
        fprintf('Final choice: "%s"\n', final_char);
    end
    
    fprintf('\n=== FINAL DIAGNOSTIC RESULT ===\n');
    fprintf('Recognized text: "%s"\n', recognizedText);
end

% Simple template matching based on basic shapes
function result = simple_template_match(char_img)
    char_img = double(char_img);
    
    % Normalize size
    char_resized = imresize(char_img, [32, 24]);
    
    % Basic geometric measurements
    total_pixels = sum(char_resized(:));
    [h, w] = size(char_resized);
    
    % Vertical and horizontal projections
    v_proj = sum(char_resized, 2);
    h_proj = sum(char_resized, 1);
    
    % Find peaks in projections
    v_peaks = findpeaks(v_proj);
    h_peaks = findpeaks(h_proj);
    
    % Calculate features
    aspect_ratio = w / h;
    density = total_pixels / (h * w);
    v_peak_count = length(v_peaks);
    h_peak_count = length(h_peaks);
    
    % Top, middle, bottom density
    top_density = sum(sum(char_resized(1:round(h/3), :))) / (round(h/3) * w);
    mid_density = sum(sum(char_resized(round(h/3):round(2*h/3), :))) / (round(h/3) * w);
    bot_density = sum(sum(char_resized(round(2*h/3):end, :))) / (round(h/3) * w);
    
    % Simple classification rules
    if density < 0.2
        result = '1'; % Very sparse
    elseif aspect_ratio < 0.4
        result = '1'; % Very narrow
    elseif v_peak_count <= 1 && h_peak_count <= 2
        if mid_density < 0.1
            result = '0'; % Hollow in middle
        else
            result = '8'; % Filled
        end
    elseif top_density > bot_density * 2
        result = 'P'; % Top heavy
    elseif bot_density > top_density * 2
        result = 'L'; % Bottom heavy
    elseif h_peak_count >= 3
        result = 'E'; % Multiple vertical segments
    else
        result = '?';
    end
end

% Feature-based recognition using more sophisticated analysis
function result = feature_based_recognition(char_img)
    char_img = double(char_img);
    char_img = imresize(char_img, [48, 32]);
    
    % Connected components analysis
    cc = bwconncomp(char_img);
    
    if cc.NumObjects == 0
        result = '?';
        return;
    end
    
    % Analyze the largest component
    stats = regionprops(cc, 'Area', 'BoundingBox', 'Eccentricity', 'Solidity');
    [~, largest_idx] = max([stats.Area]);
    main_component = stats(largest_idx);
    
    eccentricity = main_component.Eccentricity;
    solidity = main_component.Solidity;
    bbox = main_component.BoundingBox;
    aspect_ratio = bbox(3) / bbox(4);
    
    % Classification based on shape properties
    if aspect_ratio < 0.3
        result = '1';
    elseif cc.NumObjects >= 2 && solidity > 0.7
        result = 'B'; % Multiple components, solid
    elseif eccentricity < 0.5 && solidity < 0.8
        result = '0'; % Round with hole
    elseif eccentricity > 0.8
        result = '1'; % Very elongated
    elseif solidity > 0.9
        if aspect_ratio > 0.8
            result = '8'; % Square-ish and solid
        else
            result = '1'; % Tall and solid
        end
    else
        result = '?';
    end
end

result = diagnose_and_recognize(chars);