% State Identification
% First declare the plate text
plateText = fullText
fprintf(plateText)

% Define the first and the second letters from the number plate
prefix1 = plateText(1);
prefix2 = plateText(2);

% Mapping the state with the containers given
stateMap = containers.Map({'A','B','C','D','J','V','W','P','S','Q','R','M','N','F','T' 'K'}, ...
                          {'Perak','Selangor','Pahang','Kelantan','Johor','Kuala Lumpur','Kuala Lumpur','Penang', ...
                          'Sabah','Sarawak','Perlis','Melaka','Negeri Sembilan','Putrajaya', 'Terengganu', 'Kedah'});

% Determine state
if stateMap.isKey(prefix1)
    state = stateMap(prefix1);
elseif prefix2 == 'H'
    if stateMap.isKey(prefix2)
        state = stateMap(prefix2);
    else
        state = 'Unknown';
    end
elseif prefix1 == 'Z'
    % Military plates
    state = 'Military';
else
    state = 'Unknown';
end

% Print the plate text and state
fprintf('Raw fullText length: %d\n', length(plateText));
fprintf('Raw fullText content: "%s"\n', plateText);
fprintf('Plate %s\n: State=%s\n', plateText, state);