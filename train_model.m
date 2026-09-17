function train_model()
    % 1. Load logged data
    if ~exist('hil_logged_dataset.mat', 'file')
        error('hil_logged_dataset.mat not found. Run transmission and stop first.');
    end
    raw = load('hil_logged_dataset.mat').loggedData;
    
    windowSize = 200;
    numSamples = size(raw, 1);
    class_names = {'Normal', 'LG (A)', 'LL (AB)', 'LLG (AB-G)', 'LLL'};

    if numSamples < windowSize
        error('Dataset too short (%d samples). Need at least %d.', numSamples, windowSize);
    end

    % 2. Extract sliding-window RMS features
    disp('Extracting sliding-window RMS features...');
    X_features = zeros(numSamples - windowSize + 1, 6);
    y_labels = cell(numSamples - windowSize + 1, 1);
    
    idx = 1;
    for i = windowSize:numSamples
        window = raw(i - windowSize + 1:i, 1:6);
        v_rms = rms(window(:, 1:3), 1);
        i_rms = rms(window(:, 4:6), 1);
        
        X_features(idx, :) = [v_rms, i_rms];
        mode_val = raw(i, 7);
        if mode_val >= 1 && mode_val <= length(class_names)
            y_labels{idx} = class_names{mode_val};
        else
            y_labels{idx} = 'Normal';
        end
        idx = idx + 1;
    end
    
    y_cat = categorical(y_labels, class_names);

    % 3. Train Random Forest Ensemble
    disp('Training Random Forest model...');
    mdl = fitcensemble(X_features, y_cat, ...
        'Method', 'Bag', ...
        'NumLearningCycles', 100, ...
        'Learner', 'tree');

    % 4. Validate and Save
    yPred = predict(mdl, X_features);
    acc = mean(yPred == y_cat);
    fprintf('Training Set Accuracy: %.2f%%\n', acc * 100);

    save('trained_fault_model.mat', 'mdl');
    disp('Saved updated model to trained_fault_model.mat.');
end