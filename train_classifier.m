clc; clear; close all;

if ~exist('fault_dataset.mat', 'file')
    error('fault_dataset.mat missing! Run generate_dataset.m first.');
end

load('fault_dataset.mat');

% Data integrity validation
if any(isnan(dataset_features(:))) || any(isinf(dataset_features(:)))
    error('Dataset contains NaN or Inf values. Re-run generate_dataset.m.');
end

% Stratified 80/20 train/test split
cv = cvpartition(dataset_labels, 'HoldOut', 0.2);
X_train = dataset_features(training(cv), :);
y_train = dataset_labels(training(cv));
X_test  = dataset_features(test(cv), :);
y_test  = dataset_labels(test(cv));

fprintf('Training Ensemble Bagged Trees Classifier...\n');

mdl = fitcensemble(X_train, y_train, ...
    'Method', 'Bag', ...
    'NumLearningCycles', 50, ...
    'Learners', 'tree');

y_pred = predict(mdl, X_test);
accuracy = mean(y_pred == y_test) * 100;
fprintf('Model Evaluation Finalized. Test Accuracy: %.2f%%\n', accuracy);

class_names = {'Normal', 'LG (A)', 'LL (AB)', 'LLG (AB-G)', 'LLL'};
y_test_cat = categorical(y_test, 1:5, class_names);
y_pred_cat = categorical(y_pred, 1:5, class_names);

figure('Name', 'Classifier Confusion Matrix', 'Color', [1 1 1]);
cm = confusionchart(y_test_cat, y_pred_cat);
title(cm, sprintf('Random Forest Accuracy: %.2f%%', accuracy));

save('trained_fault_model.mat', 'mdl');
fprintf('Saved Model Artifact -> trained_fault_model.mat\n');