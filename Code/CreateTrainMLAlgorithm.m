function [mdlAcc,mdlLoss,classTrue,classPred,usedFreqPeaks,status] = ...
    CreateTrainMLAlgorithm(MLmodelType,trainingDataUsed,usePCA,...
    freqPeaks,trainingDataFolderPath,applicationPath)
%% This function is called from the Pass_Fail application
% It contains the code to train all of the different machine learning algorithms

% Function inputs:
% MLmodelType - The machine learning model method ('DL','kNN',ect)
% trainingDataUsed - The type of training data available (sup or unsup)
% usePCA - Use principal component analysis ('Yes' or 'No')
% freqPeaks - The estimated frequency peaks
% trainingDataFolderPath - The path to where the training data is kept
% applicationPath - The path to where the Pass_Fail app is stored

% Function outputs:
% mdlAcc - The accuracy of the trained model
% mdlLOss - The loss of the trained model
% classTrue - The actual class of the test data
% classPred - The predicted class of the test data
% usedFreqPeaks - The estimated frequency peaks which were used to train
% the model
% status - The result of the function (any errors)
% ========================================================================
% Written by Nicholas Thomas
% 25-04-2021
% ------------------------------------------------------------------------

%% Construct status struct
% This will be pass around the application and reported back to the UI
status.error = 0;
status.desc = "";
mdlAcc = NaN;
mdlLoss = NaN;
classTrue = {};
classPred = {};
usedFreqPeaks = freqPeaks;
features = length(usedFreqPeaks);


%% Create datastores and extract features
try
    if MLmodelType == "DL"
        % Need an image datastore
        files = dir(fullfile(trainingDataFolderPath,'**/*.csv'));
        for i = 1:length(files)
            name = files(i).name;
            folder = files(i).folder;
            CreateSpectrogram("Yes","Training",fullfile(folder,name),'');
        end
        
        % Create the damaged image datastore
        damagedBladeFolderPath = fullfile(trainingDataFolderPath,'Damaged');
        im_Damaged_ds = imageDatastore(damagedBladeFolderPath,...
            'IncludeSubfolders',true);
        im_Damaged_ds.Labels = repelem("D",numel(im_Damaged_ds.Files));

        % Create the undamaged image datastore
        undamagedBladeFolderPath = fullfile(trainingDataFolderPath,'Undamaged');
        im_Undamaged_ds = imageDatastore(undamagedBladeFolderPath,...
            'IncludeSubfolders',true);
        im_Undamaged_ds.Labels = repelem("UD",numel(im_Undamaged_ds.Files));

        % Create the combined image datastore with corresponding labels
        im_ds = imageDatastore([im_Damaged_ds.Files; im_Undamaged_ds.Files]);
        im_ds.Labels = [categorical(im_Damaged_ds.Labels);...
            categorical(im_Undamaged_ds.Labels)];

    else
        % Need a tabular datastore
        if trainingDataUsed == "Undamaged"
            % Only the undamaged folder
            undamagedFolderPath = fullfile(trainingDataFolderPath,'Undamaged');
            files_ds = tabularTextDatastore(undamagedFolderPath,...
                'NumHeaderLines',2,'VariableNames',["Time","ChannelA"],...
                'IncludeSubfolders',true,'FileExtensions',{'.csv'},...
                'ReadSize','file');
        else
            % Both folders required
            files_ds = tabularTextDatastore(trainingDataFolderPath,...
                'NumHeaderLines',2,'VariableNames',["Time","ChannelA"],...
                'IncludeSubfolders',true,'FileExtensions',{'.csv'},...
                'ReadSize','file');
            
            % Extract the class of the blades
            [~,files,~] = fileparts(files_ds.Files);
            classes = extractBetween(string(files),'_','-');
            knownClass = categorical(classes);
        end

        % Call the PreprocessData function for the datastore
        preprocessedFiles_ds = transform(files_ds,...
            @(data) PreprocessData(data));

        % Call the ExtractFeature function for the datastore
        ExtractedFeatures_ds = transform(preprocessedFiles_ds,...
            @(data) ExtractFeature(data,freqPeaks));

        % Extract the data and remove the unused columns
        dataOut = struct2table(readall(ExtractedFeatures_ds));
        data = removevars(dataOut,{'rawSig','rawSigTime','f','amp',...
            'phase','extractedFreqs','ampAtExtractedFreqs'});

        if usePCA == "Yes"
            % Perform PCA to reduce less useful features and standarise
            % https://www.mathworks.com/help/stats/pca.html
            [pcCoeff,transformedData,~,~,percentexp,mean] = ...
                pca(table2array(data));

            totalPercentage = 0;
            for idx = 1:length(percentexp)
                % Output index where it has 97.5% variation
                totalPercentage = totalPercentage + percentexp(idx);
                if totalPercentage >= 97.5
                    break
                end
            end
            
            features = idx;
            featReduction = '-PCA-';
            PCA = struct('coeff',pcCoeff,'mu',mean,'index',idx);
            dataMat = transformedData(:,1:idx);
            data = array2table(dataMat);
        else
            featReduction = '-';
            PCA = struct();
        end      
    end
    
catch ME
    status.error = 1;
    status.desc = append('Error in CreateTrainMLAlgorithm.m: ',ME.message);
    return
end


%% Create the machine learning models
% This is where new models can be added in the switch case structure
try
    if trainingDataUsed == "Undamaged"
        % Train undamaged models
        mdl = data;
        trainingData = "UD only";
        mdlAcc = "NA";
        mdlLoss = "NA";

        switch MLmodelType
            case 'Basic'
                fileName = ['model-Basic',featReduction,'Features-',...
                    num2str(features)];
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','usedFreqPeaks','trainingData','mdlAcc');
                
            case 'DBSCAN'
                % Fit the correct epsilon for the undamaged training data
                minpts = features + 1;
                epsilonTest = 1:1:100;
                for epsilon = epsilonTest
                    classes = dbscan(table2array(data),epsilon,minpts);
                    outlier(epsilon) = ismember(-1,classes);
                end
                
                nonOutlierIdx = find(outlier == 0);
                firstIdx = nonOutlierIdx(1);
                epsilon = epsilonTest(firstIdx); % Required epsilon
            
                fileName = ['model-DBSCAN',featReduction,'Features-',...
                    num2str(features)];
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','usedFreqPeaks','trainingData','mdlAcc',...
                    'minpts','epsilon');
                
            case 'Gaussian'
                % Fit distributions to find values of AIC and BIC which
                % show the quality of fit for 1-10 clusters
                for k = 1:10
                    GMModels{k} = fitgmdist(table2array(data),k,...
                        'RegularizationValue',0.01);
                    AIC(k) = GMModels{k}.AIC;
                    BIC(k) = GMModels{k}.BIC;
                end
                
                fileName = ['model-Gaussian',featReduction,'Features-',...
                    num2str(features)];
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','usedFreqPeaks','trainingData','mdlAcc',...
                    'AIC','BIC');
                
            case 'SpectralCluster'
                fileName = ['model-SpectralCluster',featReduction,'Features-',...
                    num2str(features)];
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','usedFreqPeaks','trainingData','mdlAcc');
        end
    else
        % Train undamaged and damaged models
        if MLmodelType ~= "DL" && MLmodelType ~= "ShallowNN"
            % This case for all conventional ML models
            
            % Split up data to keep some for testing
            data.Class = knownClass;
            pt = cvpartition(data.Class,"Holdout",0.15);
            dataTrain = data(training(pt),:);
            dataTest = data(test(pt),:);
            
            % Construct partition to have the highest validation (leaveout)
            cvpt = cvpartition(dataTrain.Class,"leaveout");
            opts = struct("CVPartition",cvpt,"Verbose",1);
        end
        
        switch MLmodelType
            case 'AUTO'
                % Automatic selection of the best model
                % It takes a very long time to optimise
                mdl = fitcauto(dataTrain,"Class","Learners","auto",...
                    "OptimizeHyperparameters",'auto',...
                    "HyperparameterOptimizationOptions",opts);
                
                if contains('compact',class(mdl))
                    mdlLoss = 100 * loss(mdl,dataTrain);
                else
                    mdlLoss = 100 * resubLoss(mdl);
                end
                
                % Info about the model
                [classPred,~] = predict(mdl,dataTest);
                classTrue = dataTest.Class;
                mdlAcc = 100 * ...
                    (sum(nnz(classPred == classTrue))/length(classTrue));
                
                fileName = ['model-AUTO',featReduction,'Features-',...
                    num2str(features)];
                trainingData = "UD + D";
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','PCA','usedFreqPeaks','trainingData','mdlAcc');
                
            case 'Tree'
                % Binary tree classification model
                mdl = fitctree(dataTrain,"Class","OptimizeHyperparameters",...
                    "all","HyperparameterOptimizationOptions",opts);                
                
                % Info about the model
                mdlLoss = 100 * resubLoss(mdl);
                [classPred,~] = predict(mdl,dataTest);
                classTrue = dataTest.Class;
                mdlAcc = 100 * ...
                    (sum(nnz(classPred == classTrue))/length(classTrue));
                
                fileName = ['model-Tree',featReduction,'Features-',...
                    num2str(features)];
                trainingData = "UD + D";
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','PCA','usedFreqPeaks','trainingData','mdlAcc');
                
            case 'kNN'
                % Nearest neighbors model
                % Categorises points on their distance to points in training data
                mdl = fitcknn(dataTrain,"Class","OptimizeHyperparameters",...
                    "all","HyperparameterOptimizationOptions",opts);
                
                % Info about the model
                mdlLoss = 100 * resubLoss(mdl);
                [classPred,~] = predict(mdl,dataTest);
                classTrue = dataTest.Class;
                mdlAcc = 100 * ...
                    (sum(nnz(classPred == classTrue))/length(classTrue));
                
                fileName = ['model-kNN',featReduction,'Features-',...
                    num2str(features)];
                trainingData = "UD + D";
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','PCA','usedFreqPeaks','trainingData','mdlAcc');
                
            case 'SVM'
                % Support vector machine model
                % Only usable for 2 distinct class problems
                % Need data to be normalised (mean at 0) so will not be used
                mdl = fitcsvm(dataTrain,"Class","OptimizeHyperparameters",...
                    "all","HyperparameterOptimizationOptions",opts);
                mdl = fitPosterior(mdl);
                
                % Info about the model
                mdlLoss = 100 * resubLoss(mdl);
                [classPred,~] = predict(mdl,dataTest);
                classTrue = dataTest.Class;
                mdlAcc = 100 * ...
                    (sum(nnz(classPred == classTrue))/length(classTrue));
                
                fileName = ['model-SVM',featReduction,'Features-',...
                    num2str(features)];
                trainingData = "UD + D";
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','PCA','usedFreqPeaks','trainingData','mdlAcc');
                
            case 'NB'
                % Naive Bayes model
                % Assumes predictors are independent of each other
                mdl = fitcnb(dataTrain,"Class","OptimizeHyperparameters",...
                    "all","HyperparameterOptimizationOptions",opts);
                
                % Info about the model
                mdlLoss = 100 * resubLoss(mdl);
                [classPred,~] = predict(mdl,dataTest);
                classTrue = dataTest.Class;
                mdlAcc = 100 * ...
                    (sum(nnz(classPred == classTrue))/length(classTrue));
                
                fileName = ['model-NB',featReduction,'Features-',...
                    num2str(features)];
                trainingData = "UD + D";
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','PCA','usedFreqPeaks','trainingData','mdlAcc');
                
            case 'DA'
                % Discriminant analysis classification model
                % Assumes different classes generate data based on Gaussian distribution
                mdl = fitcdiscr(dataTrain,"Class","OptimizeHyperparameters",...
                    "all","HyperparameterOptimizationOptions",opts);
                
                % Info about the model
                mdlLoss = 100 * resubLoss(mdl);
                [classPred,~] = predict(mdl,dataTest);
                classTrue = dataTest.Class;
                mdlAcc = 100 * ...
                    (sum(nnz(classPred == classTrue))/length(classTrue));
                
                fileName = ['model-DA',featReduction,'Features-',...
                    num2str(features)];
                trainingData = "UD + D";
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','PCA','usedFreqPeaks','trainingData','mdlAcc');

            case 'NN'
                % This is only in MATLAB 2021 so implementing now
%                 % Classification neural network
% 
%                 % Construct and train the model
%                 mdl = fitcnet(dataTrain,"Class","Leaveout",'on',...
%                     "Standardize",true);
% 
%                 mdlLoss = 100 * resubLoss(mdl);
%                 [classPred,conf] = predict(mdl,dataTest);
%                 classTrue = dataTest.Class;
%                 mdlAcc = 100 * ...
%                    (sum(nnz(classPred == classTrue))/length(classTrue));
% 
%                 % Info about the model
%                 fileName = ['model-NN',featReduction,'Features-',...
%                    num2str(features)];
%                 trainingData = "UD + D";
%                 save(fullfile(applicationPath,fileName),'MLmodelType',...
%                      'mdl','PCA','usedFreqPeaks','trainingData','mdlAcc');
                
            case 'ShallowNN'
                % The neural network case
                net = patternnet(15); % Number of neurons per layer
                
                % Split up features into separate DS
                net.divideParam.trainRatio = 70/100;
                net.divideParam.valRatio = 15/100;
                net.divideParam.testRatio = 15/100;
                
                % Format data and true class
                data = table2array(data)';
                classes = dummyvar(knownClass)';
                
                % Format used to analyse which class is actually is
                [~,classIdx] = max(classes(:,1));
                format = struct(string(knownClass(1)),classIdx);
                
                % Train the network
                [net,tr] = train(net,data,classes);
                
                % Info about the network
                mdlLoss = 100 * tr.best_tperf;
                scoreTest = net(data(:,tr.testInd));
                [~,classPred] = max(scoreTest);
                classTrue = double(knownClass(tr.testInd));
                mdlAcc = 100 * ...
                    sum(nnz(classPred' == classTrue))/length(classTrue);
                
                mdl = net;
                fileName = ['model-ShallowNN',featReduction,'Features-',...
                    num2str(features)];
                trainingData = "UD + D";
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','PCA','format','usedFreqPeaks','trainingData',...
                    'mdlAcc');
                
            case 'DL'
                % The deep learning case
                % It takes a very long time to train
                
                [trainImgs,valImgs,testImgs] = splitEachLabel(im_ds,...
                    0.7,0.15,0.15, "randomized");
                
                % Split up images into separate DS
                train_ds = augmentedImageDatastore([224 224],trainImgs);
                val_ds = augmentedImageDatastore([224 224],valImgs);
                test_ds = augmentedImageDatastore([224 224],testImgs);
                
                % https://www.mathworks.com/help/deeplearning/ug/
                % pretrained-convolutional-neural-networks.html
                % Can change the pretrained net that is used
                
                net = resnet50; % Must have input 224x224
                
                % Transfer learning
                if isa(net,'SeriesNetwork') 
                    lgraph = layerGraph(net.Layers); 
                else
                    lgraph = layerGraph(net);
                end 
                
                % Layers to replace
                [learnableLayer,classLayer] = findLayersToReplace(lgraph);

                numClasses = numel(categories(trainImgs.Labels));
                if isa(learnableLayer,'nnet.cnn.layer.FullyConnectedLayer')
                    newLearnableLayer = fullyConnectedLayer(numClasses,...
                        'Name','new_fc');
                    
                elseif isa(learnableLayer,'nnet.cnn.layer.Convolution2DLayer')
                    newLearnableLayer = convolution2dLayer(1,numClasses,...
                        'Name','new_conv');
                end
                lgraph = replaceLayer(lgraph,learnableLayer.Name,newLearnableLayer);
                
                newClassLayer = classificationLayer('Name','new_classoutput');
                lgraph = replaceLayer(lgraph,classLayer.Name,newClassLayer);
                
                % Training options (these have not be optimised and are not
                % optimised automatically)
                options = trainingOptions("adam", ...
                    "Plots","training-progress", ...
                    "ValidationData",val_ds,...
                    "ValidationFrequency",5,...
                    "ValidationPatience",5,...
                    "LearnRateSchedule","piecewise",...
                    "LearnRateDropPeriod",2,...
                    "MaxEpochs",10);
                
                % Train the network
                [net,info] = trainNetwork(train_ds,lgraph,options);
                
                % Info about the network
                mdlLoss = 100 * info.TrainingLoss(end);
                mdlAcc =  info.TrainingAccuracy(end);
                [classPred,~] = classify(net,test_ds);
                classTrue = testImgs.Labels;
                
                fileName = ['model-DL-','ResNet50'];
                mdl = net;
                usedFreqPeaks = [];
                trainingData = "UD + D";
                save(fullfile(applicationPath,fileName),'MLmodelType',...
                    'mdl','usedFreqPeaks','trainingData','mdlAcc');
                
            otherwise
                status.error = 1;
                status.desc = 'Non valid ML model has been requested';
        end
    end
   
catch ME
    status.error = 1;
    status.desc = append('Error in CreateTrainMLAlgorithm.m: ',ME.message);
end

end
