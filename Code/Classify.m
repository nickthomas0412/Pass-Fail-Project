function [classPred,probability] = Classify(MLmodel,data)
%% This function classifies the unknown blade under test 

% Function inputs:
% MLmodel - Structure containing the machine learning model to be used
% data - The test data to be compared to the machine learning model 

% Function outputs:
% classPred - The predicited classification ('UD' or 'D')
% probability - The probability the blade is 'UD'

% ========================================================================
% Written by Nicholas Thomas
% 25-04-2021
% ------------------------------------------------------------------------

% Classify the blade depending on training dat used and model type
%% This is where new models can be added in the switch case structure
if MLmodel.trainingData == "UD only"
    % Classify undamaged only models
    testData = table2array(data);
    trainData = table2array(MLmodel.mdl);
    inputData = trainData;
    inputData(end+1,:) = testData;

    switch MLmodel.MLmodelType
        case "Basic"
            mu = mean(trainData,1);
            stdev = std(trainData);
            
            for i = 1:length(mu)
                diff(i) = abs(mu(i) - testData(i));
                numStds(i) = diff(i) / stdev(i);
                if numStds(i) > 6
                    % Prevent very large numbers if std is very small
                    numStds(i) = 6;
                end
            end
            
            meanNumStds = mean(numStds);
            
            if meanNumStds > 3
                % 3 standard deviations are considered to be an outlier
                classPred = "D";
            else
                classPred = "UD";
            end
            probability = "NA";
               
        case "Gaussian"
            %https://www.mathworks.com/help/stats/
            %clustering-using-gaussian-mixture-models.html
            GMModels = fitgmdist(inputData,1,'RegularizationValue',0.01);
            AIC = GMModels.AIC;

            % If new file increases AIC by 10% then outlier
            if MLmodel.AIC(1) > 0 
                threshold = 1.1 * MLmodel.AIC(1);
            else
                threshold = 0.9 * MLmodel.AIC(1);
            end
            
            if AIC > threshold 
                classPred = "D";
            else
                classPred = "UD";
            end
            probability = "NA";

        case "DBSCAN"
            %https://www.mathworks.com/help/stats/dbscan.html
            % Give a new file 10% margin on becoming an outlier
            epsilon = round(1.1 * MLmodel.epsilon);
            minpts = round(1.1 * MLmodel.minpts);
            
            classes = dbscan(inputData,epsilon,minpts);
            
            % If there is an outlier then there will be a -1 in classes
            if ismember(-1,classes)
                classPred = "D";
            else
                classPred = "UD";
            end
            probability = "NA";
            
            case "SpectralCluster"
            %https://www.mathworks.com/help/stats/
            %partition-data-using-spectral-clustering.html
            
            pause(1); % Need to pause or it crashes sometimes
            [~,~,eigenValues] = spectralcluster(inputData,7,...
                'ClusterMethod','kmedoids','NumNeighbors',10);
            
            % Eigenvalues close to zero represent a cluster 
            classes = sum(eigenValues < 1e-5);
            
            if classes > 1
                classPred = "D";
            else
                classPred = "UD";
            end
            probability = "NA";
    end
    
else
    % Classify undamaged and damaged models
    switch MLmodel.MLmodelType
        case "DL"
            % Classify using the deep learning case
            [classPred,confidence] = classify(MLmodel.mdl,data);
            if classPred == categorical("UD")
                probability = 100 * max(confidence);
            else
                probability = 100 * min(confidence);
            end
            
        case "ShallowNN"
            % Classify using the shallow neural network
            
            if isfield(MLmodel.PCA,'coeff')
                % Transform data if a PCA was used
                % https://www.mathworks.com/help/stats/pca.html
                data = (table2array(data) - MLmodel.PCA.mu) * ...
                    MLmodel.PCA.coeff(:,1:MLmodel.PCA.index);
            else
                data = table2array(data);
            end
            
            % Logic below is required because the shallowNN is a special case
            scoreTest = MLmodel.mdl(data');
            [~,classPredScore] = max(scoreTest);
            
            classType = string(fieldnames(MLmodel.format));
            classIdxConversion = MLmodel.format.(classType);
            
            if classType == "D"
                classTypeOther = "UD";
            elseif classType == "UD"
                classTypeOther = "D";
            end
            
            if classPredScore == classIdxConversion
                classPred = categorical(classType);
            else
                classPred = categorical(classTypeOther);
            end
            
            if (classPred == categorical("UD") && classType == "UD") ||...
                    (classPred == categorical("D") && classType == "UD")
                probability = 100 * scoreTest(classIdxConversion);
            elseif (classPred == categorical("UD") && classType == "D") ||...
                    (classPred == categorical("D") && classType == "D")
                if classIdxConversion == 1
                    probability = 100 * scoreTest(2);
                elseif classIdxConversion == 2
                    probability = 100 * scoreTest(1);
                end
            end
            
        otherwise
            % Classify using All normal conventional ML methods
            if isfield(MLmodel.PCA,'coeff')
                % Transform data if a PCA was used
                data = (table2array(data) - MLmodel.PCA.mu) * ...
                    MLmodel.PCA.coeff(:,1:MLmodel.PCA.index);
            end
            
            [classPred,confidence] = predict(MLmodel.mdl,data);
            if classPred == categorical("UD")
                probability = 100 * max(confidence);
            else
                probability = 100 * min(confidence);
            end
    end  
end
