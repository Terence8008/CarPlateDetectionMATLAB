% Character Recognition
    % Define the folder path ( You need to declare which plate document u
    % will using cause detection occurs many license plate scenario
    % file path
    
    folder_path = 'C:\Users\dongk\OneDrive\Documents\MATLAB\plate_1_fixed_characters';
    
    % For each char.png it will process each image and show the images for OCR
    charFiles = dir(fullfile(folder_path, 'char*.png'));
    recognizedText = cell(length(charFiles), 1); % Store each of the text result
    
    for i = 1:length(charFiles)
        img = imread(fullfile(folder_path, charFiles(i).name));
    
        % Display the image to see what we're working with
        figure;
        imshow(img);
        title(sprintf('Character %d: %s', i, charFiles(i).name));
        
        % Perform OCR
        ocrResults = ocr(img, LayoutAnalysis="block");
        recognizedText{i} = ocrResults.Text;
    
        % Display Result
        fprintf('Character %d (%s): "%s"\n', i, charFiles(i).name, strtrim(recognizedText{i}));
    end
    
    % Combine all recognized characters
    fullText = strjoin(cellfun(@strtrim, recognizedText, 'UniformOutput', false), '');
    fprintf('Complete recognized text: %s\n', fullText);

