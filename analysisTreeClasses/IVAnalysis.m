classdef IVAnalysis < AnalysisTree
    properties
        StartTime = 100;
        EndTime = 150;
    end
    
    methods
        function obj = IVAnalysis(cellData, dataSetName, params)
            if nargin < 3
                params.deviceName = 'Amplifier_Ch1';
            end
            
            nameStr = [cellData.savedFileName ': ' dataSetName ': IVAnalysis'];
            obj = obj.setName(nameStr);
            obj = obj.copyAnalysisParams(params);
            dataSet = cellData.savedDataSets(dataSetName);
            obj = obj.copyAnalysisParams(params);
            obj = obj.copyParamsFromSampleEpoch(cellData, dataSet, ...
                {'RstarMean', 'RstarIntensity', 'spotSize', 'offsetX', 'offsetY'});
            obj = obj.buildCellTree(1, cellData, dataSet, {'holdSignal'}); %fix this for amp2holdSignal after protocol is fixed!
        end
        
        function obj = doAnalysis(obj, cellData)
            rootData = obj.get(1);
            leafIDs = obj.findleaves();
            L = length(leafIDs);
            for i=1:L
                curNode = obj.get(leafIDs(i));
                outputStruct = getEpochResponses_WC(cellData, curNode.epochID, ...
                    'DeviceName', rootData.deviceName);
                outputStruct = getEpochResponseStats(outputStruct);
                curNode = mergeIntoNode(curNode, outputStruct);
                obj = obj.set(leafIDs(i), curNode);
            end
            
            obj = obj.percolateUp(leafIDs, ...
                'splitValue', 'holdSignal');
            
            [byEpochParamList, singleValParamList, collectedParamList] = getParameterListsByType(curNode);
            obj = obj.percolateUp(leafIDs, byEpochParamList, byEpochParamList);
            obj = obj.percolateUp(leafIDs, singleValParamList, singleValParamList);
            obj = obj.percolateUp(leafIDs, collectedParamList, collectedParamList);
            
            rootData = obj.get(1);
            rootData.stimParameterList = {'holdSignal'};
            rootData.byEpochParamList = byEpochParamList;
            rootData.singleValParamList = singleValParamList;
            rootData.collectedParamList = collectedParamList;
            obj = obj.set(1, rootData);
            
        end
    end
    
    methods(Static)
%         function plotData(node, cellData)
%             rootData = node.get(1);
%             errorbar(rootData.holdSignal, rootData.respMean, rootData.respSEM);
%             xlabel('Hold signal (mV)');
%             ylabel('Peak current (pA)');
%         end
        
        function plotMeanTraces(node, cellData)
            rootData = node.get(1);
            chInd = node.getchildren(1);
            L = length(chInd);
            ax = axes;
            for i=1:L
                hold(ax, 'on');
                epochInd = node.get(chInd(i)).epochID;
                cellData.plotMeanData(epochInd, true, [], rootData.deviceName, ax);
            end
            hold(ax, 'off');
        end
        
    end
    
end