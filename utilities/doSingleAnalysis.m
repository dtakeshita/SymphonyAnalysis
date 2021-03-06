function resultTree = doSingleAnalysis(cellName, analysisClassName, cellFilter, epochFilter)
if nargin < 4
    epochFilter = [];
end
if nargin < 3
    cellFilter = [];
end

global ANALYSIS_FOLDER
global PREFERENCE_FILES_FOLDER

%Open DataSetsAnalyses.txt file that defines the mapping between data set
%names and analysis classes
fid = fopen([PREFERENCE_FILES_FOLDER 'DataSetAnalyses.txt'], 'r');
analysisTable = textscan(fid, '%s\t%s');
fclose(fid);

%find correct row in this table
Nanalyses = length(analysisTable{1});
analysisInd = 0;
for i=1:Nanalyses
    if strcmp(analysisTable{2}{i}, analysisClassName);
        analysisInd = i; 
        break;
    end
end
if analysisInd == 0
    disp(['Error: analysis ' analysisClassName ' not found in DataSetAnalyses.txt']);
    resultTree = [];
    return;
end

%Deal with cell names that include '-Ch1' or '-Ch2'
%cellName_orig = cellName;
params_deviceOnly.deviceName = 'Amplifier_Ch1';
loc = strfind(cellName, '-Ch1');
if ~isempty(loc)
    cellName = cellName(1:loc-1);
end
loc = strfind(cellName, '-Ch2');
if ~isempty(loc)
    cellName = cellName(1:loc-1);
    params_deviceOnly.deviceName = 'Amplifier_Ch2';
end

%set up output tree
resultTree = AnalysisTree;
nodeData.name = ['Single analysis tree: ' cellName ' : ' analysisClassName];
nodeData.device = params_deviceOnly.deviceName;
resultTree = resultTree.set(1, nodeData);

%load cellData
cellData = loadAndSyncCellData(cellName);
%load([ANALYSIS_FOLDER 'cellData' filesep cellName]);
dataSetKeys = cellData.savedDataSets.keys;

%run cell filter 
if ~isempty(cellFilter);
    analyzeThisCell = cellData.filterCell(cellFilter.makeQueryString());
    if ~analyzeThisCell
        resultTree = [];
        return;
    end
end

for i=1:length(dataSetKeys);
    T = [];
    analyzeDataSet = false;
    curDataSet = dataSetKeys{i};
    if strfind(curDataSet, analysisTable{1}{analysisInd}) %if correct data set type
        %evaluate epochFilter
        if ~isempty(epochFilter)
            filterOut = cellData.filterEpochs(epochFilter.makeQueryString(), cellData.savedDataSets(curDataSet));
            if length(filterOut) == length(cellData.savedDataSets(curDataSet)) %all epochs match filter
                analyzeDataSet = true;
            end
        else
            analyzeDataSet = true;
        end
    end
    if analyzeDataSet
        usePrefs = false;
        if ~isempty(cellData.prefsMapName)
            prefsMap = loadPrefsMap(cellData.prefsMapName);
            [hasKey, keyName] = hasMatchingKey(prefsMap, curDataSet); %loading particular parameters from prefsMap
            if hasKey
                usePrefs = true;
                paramSets = prefsMap(keyName);
                for p=1:length(paramSets)
                    T = [];
                    curParamSet = paramSets{p};
                    load([ANALYSIS_FOLDER 'analysisParams' filesep analysisClassName filesep curParamSet]); %loads params
                    params.deviceName = params_deviceOnly.deviceName;
                    params.parameterSetName = curParamSet;
                    params.class = analysisClassName;
                    params.cellName = cellName;
                    eval(['T = ' analysisClassName '(cellData,' '''' curDataSet '''' ', params);']);
                    T = T.doAnalysis(cellData);
                    
                    if ~isempty(T)
                        resultTree = resultTree.graft(1, T); 
                    end
                end
            end
        end
        
        if ~usePrefs
            params = params_deviceOnly;
            params.class = analysisClassName;
            params.cellName = cellName;
            eval(['T = ' analysisClassName '(cellData,' '''' curDataSet '''' ', params);']);
            T = T.doAnalysis(cellData);
            
            if ~isempty(T)
                resultTree = resultTree.graft(1, T); 
            end
        end
        
    end
end

if length(resultTree.Node) == 1 %if nothing found for this cell
    %return empty so this does not get grafted onto anything
    resultTree = [];
end
