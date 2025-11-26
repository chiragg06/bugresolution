public without sharing class TypeaheadSelectionController {

    @AuraEnabled(cacheable = true)
    public static List<Object> getTypeAheadResults(String searchedValue, String selectedPill) {
        System.debug('TypeaheadSelectionController.getTypeAheadResults START');
        System.debug('Input searchedValue: ' + searchedValue);
        System.debug('Input selectedPill: ' + selectedPill);

        if(selectedPill == ''){
            System.debug('Empty selectedPill detected in the first if block.');
        }
        else if(selectedPill == ''){
            System.debug('Empty selectedPill detected in the second if block.');
        }
        else if(selectedPill == ''){
             System.debug('Empty selectedPill detected in the third if block.');
        }
        
        Map<String, Object> inputMap = new Map<String, Object>();
        inputMap.put('componentName', searchedValue);
        inputMap.put('componentType', selectedPill);
        System.debug('Helper inputMap: ' + JSON.serialize(inputMap));
        
        Map<String, Object> outputMap = new Map<String, Object>();
        Map<String, Object> options = new Map<String, Object>();
        
        TypeaheadServiceHelper helper = new TypeaheadServiceHelper();
        
        List<String> validPills = new List<String>{
            'LWC',
            'AuraDefinitionBundle',
            'ApexClass',
            'ApexTrigger',
            'Flow'
        };
        System.debug('Valid Pills: ' + validPills);
                    
        if (validPills.contains(selectedPill)) {
            String methodName = 'get' + selectedPill + 's';
            System.debug('Pill is valid. Invoking helper method: ' + methodName);
            helper.invokeMethod(methodName, inputMap, outputMap, options);
            System.debug('Helper outputMap after invocation: ' + JSON.serialize(outputMap));
        } else {
            System.debug('Selected pill "' + selectedPill + '" is not in the valid list. No helper method will be invoked.');
        }
        
        
        if (outputMap.containsKey('success') && outputMap.get('success') == false) {
            String errorMessage = 'Error occurred while fetching data: ' + outputMap.get('error');
            System.debug(LoggingLevel.ERROR, 'Error from helper: ' + errorMessage);
            throw new AuraHandledException(errorMessage);
        }
        
        // Ensure that the output from the helper is always a List before casting.
        Object rawResult = outputMap.get(selectedPill + 's');
        System.debug('Raw result from outputMap for key "' + selectedPill + 's": ' + rawResult);
        
        if (rawResult instanceof List<Object>) {
            List<Object> finalResult = (List<Object>) rawResult;
            System.debug('Result is a List. Returning ' + finalResult.size() + ' items.');
            System.debug('TypeaheadSelectionController.getTypeAheadResults END');
            return finalResult;
        } else {
            System.debug('TypeaheadSelectionController.getTypeAheadResults END - Returning empty list.');
            return new List<Object>();
        }
    }

    @AuraEnabled
    public static ComponentAgentResult processComponentSelection(
        String componentType,
        String componentName,
        String componentId,
        String sessionId
    ) {
        System.debug('TypeaheadSelectionController.processComponentSelection START');
        System.debug('Input componentType: ' + componentType);
        System.debug('Input componentName: ' + componentName);
        System.debug('Input componentId: ' + componentId);
        System.debug('Input sessionId: ' + sessionId);
        
        ComponentAgentResult result = new ComponentAgentResult();
        
        try {
            String userMessage =
                'Retrieve the component details of type \'' + componentType +
                '\' for component \'' + componentName +
                '\' with ID \'' + componentId + '\'';
            System.debug('Constructed User Message for Agent: ' + userMessage);
            
            System.debug('Creating custom invocable action "generateAiAgentResponse" for agent "ComponentKnowledgeAgent"');
            Invocable.Action action = Invocable.Action.createCustomAction(
                'generateAiAgentResponse',
                'ComponentKnowledgeAgent'
            );
            
            System.debug('Setting "userMessage" invocation parameter.');
            action.setInvocationParameter('userMessage', userMessage);
            
            if (sessionId != null) {
                System.debug('Setting "sessionId" invocation parameter.');
                action.setInvocationParameter('sessionId', sessionId);
            } else {
                System.debug('SessionId is null, not setting it as an invocation parameter.');
            }
            
            System.debug('Invoking the action.');
            List<Invocable.Action.Result> results = action.invoke();
            System.debug('Action invocation complete. Checking agent results. Is the results list empty? ' + results.isEmpty());
            
            if (!results.isEmpty()) {
                System.debug('Results list is not empty. Processing first result.');
                Map<String, Object> outputParams = results[0].getOutputParameters();
                System.debug('Full Agent Output Parameters: ' + JSON.serialize(outputParams));
                
                if (outputParams.containsKey('agentResponse')) {
                    System.debug('Found "agentResponse" key in output parameters.');
                    String jsonStr = (String) outputParams.get('agentResponse');
                    System.debug('Raw agentResponse JSON String: ' + jsonStr);
                    
                    System.debug('Deserializing agentResponse JSON string.');
                    Map<String, Object> parsed =
                        (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
                    System.debug('Parsed agentResponse Map: ' + JSON.serializePretty(parsed));
                    
                    result.value = (String) parsed.get('value');
                    result.sessionId = (String) parsed.get('sessionId');
                    System.debug('Extracted Result Value: ' + result.value);
                    System.debug('Extracted Session ID: ' + result.sessionId);
                    
                    result.rawResponse = jsonStr;
                    System.debug('Final result object before returning: ' + JSON.serialize(result));
                    System.debug('TypeaheadSelectionController.processComponentSelection END');
                    return result;
                } else {
                     System.debug(LoggingLevel.WARN, '"agentResponse" key not found in output parameters.');
                }
            } else {
                System.debug(LoggingLevel.WARN, 'Invocable action returned an empty results list.');
            }
            
            result.value = 'No response from Agent';
            System.debug('No valid response from agent. Returning default message.');
            System.debug('TypeaheadSelectionController.processComponentSelection END');
            return result;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Exception in processComponentSelection: ' + e.getTypeName() + ' | ' + e.getMessage() + ' | StackTrace: ' + e.getStackTraceString());
            result.value = 'Error: ' + e.getMessage();
            System.debug('TypeaheadSelectionController.processComponentSelection END - with exception');
            return result;
        }
    }
    
    @AuraEnabled
    public static ComponentAgentResult removeComponentFromConversation(
        String componentType,
        String componentName,
        String componentId,
        String sessionId
    ) {
        System.debug('TypeaheadSelectionController.removeComponentFromConversation START');
        System.debug('Input componentType: ' + componentType);
        System.debug('Input componentName: ' + componentName);
        System.debug('Input componentId: ' + componentId);
        System.debug('Input sessionId: ' + sessionId);

        ComponentAgentResult result = new ComponentAgentResult();
        
        try {
            
            // -------------------------------------------------------------
            // 🟣 Build Removal Prompt — EXACTLY as requested
            // -------------------------------------------------------------
            String userMessage =
                'Remove the component of type \'' + componentType +
                '\' named \'' + componentName +
                '\' with ID \'' + componentId +
                '\' from the conversation memory. Forget all details related to it.';
            System.debug('Constructed User Message for Agent (Removal): ' + userMessage);
            
            // -------------------------------------------------------------
            // 🟣 Invoke Agent
            // -------------------------------------------------------------
            System.debug('Creating custom invocable action "generateAiAgentResponse" for agent "ComponentKnowledgeAgent"');
            Invocable.Action action = Invocable.Action.createCustomAction(
                'generateAiAgentResponse',
                'ComponentKnowledgeAgent'
            );
            
            System.debug('Setting "userMessage" invocation parameter.');
            action.setInvocationParameter('userMessage', userMessage);
            
            // Only pass session ID if available
            if (sessionId != null) {
                System.debug('Setting "sessionId" invocation parameter.');
                action.setInvocationParameter('sessionId', sessionId);
            } else {
                System.debug('SessionId is null, not setting it as an invocation parameter.');
            }
            
            System.debug('Invoking the action for removal.');
            List<Invocable.Action.Result> results = action.invoke();
            System.debug('Action invocation complete. Checking agent results. Is the results list empty? ' + results.isEmpty());
            
            if (!results.isEmpty()) {
                System.debug('Results list is not empty. Processing first result.');
                Map<String, Object> params = results[0].getOutputParameters();
                System.debug('Full Agent Output Parameters for removal: ' + JSON.serialize(params));

                if (params.containsKey('agentResponse')) {
                    System.debug('Found "agentResponse" key in output parameters.');
                    String jsonStr = (String) params.get('agentResponse');
                    System.debug('Raw agentResponse JSON String: ' + jsonStr);
                    
                    System.debug('Deserializing agentResponse JSON string.');
                    Map<String, Object> parsed =
                        (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
                    System.debug('Parsed agentResponse Map: ' + JSON.serializePretty(parsed));
                    
                    result.value = (String) parsed.get('value');
                    result.sessionId = (String) parsed.get('sessionId');
                    result.rawResponse = jsonStr;
                    System.debug('Extracted Result Value: ' + result.value);
                    System.debug('Extracted Session ID: ' + result.sessionId);
                    
                    System.debug('Final result object before returning: ' + JSON.serialize(result));
                    System.debug('TypeaheadSelectionController.removeComponentFromConversation END');
                    return result;
                } else {
                     System.debug(LoggingLevel.WARN, '"agentResponse" key not found in output parameters.');
                }
            } else {
                 System.debug(LoggingLevel.WARN, 'Invocable action returned an empty results list.');
            }
            
            result.value = 'No response from Agent.';
            System.debug('No valid response from agent. Returning default message.');
            System.debug('TypeaheadSelectionController.removeComponentFromConversation END');
            return result;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Exception in removeComponentFromConversation: ' + e.getTypeName() + ' | ' + e.getMessage() + ' | StackTrace: ' + e.getStackTraceString());
            result.value = 'Error removing component: ' + e.getMessage();
            System.debug('TypeaheadSelectionController.removeComponentFromConversation END - with exception');
            return result;
        }
    }
    
   @AuraEnabled
    public static List<String> getMetadataTypes() {
        System.debug('TypeaheadSelectionController.getMetadataTypes START');
        List<String> types = new List<String>();
        
        try {
            System.debug('Instantiating MetadataService.MetadataPort.');
            // Instantiate Metadata API service using Named Credential
            MetadataService.MetadataPort svc = new MetadataService.MetadataPort();
            
            // Override endpoint to use Named Credential (ApexMDAPI)
            svc.endpoint_x = 'callout:MetadataAPI/services/Soap/m/61.0';
            System.debug('Setting Metadata API endpoint to: ' + svc.endpoint_x);
            
            // Use OAuth token provided by Named Credential
            svc.SessionHeader = new MetadataService.SessionHeader_element();
            svc.SessionHeader.sessionId = '{!$Credential.OAuthToken}';
            System.debug('Setting SessionHeader.sessionId.');
            
            // Call describeMetadata
            System.debug('Calling MetadataService.describeMetadata for API version 61.0.');
            MetadataService.DescribeMetadataResult dm = svc.describeMetadata(61.0D);
            System.debug('describeMetadata call complete. Result object received.');
            
            // JSON workaround to avoid retrievable / retrieveable variations
            String jsonText = JSON.serialize(dm.metadataObjects);
            // Log only a substring in case the response is huge
            System.debug('Serialized metadataObjects (first 500 chars): ' + (jsonText != null && jsonText.length() > 500 ? jsonText.substring(0, 500) : jsonText));
            List<Object> objects = (List<Object>) JSON.deserializeUntyped(jsonText);
            System.debug('Deserialized metadata objects. Count: ' + (objects != null ? objects.size() : 0));
            
            Boolean hasRetrieveable = false;
            Boolean hasRetrievable = false;
            
            if (!objects.isEmpty()) {
                Map<String, Object> first = (Map<String, Object>) objects[0];
                hasRetrieveable = first.containsKey('retrieveable');
                hasRetrievable  = first.containsKey('retrievable');
                System.debug('Checking for retrievable flags. hasRetrieveable (with ea): ' + hasRetrieveable + ', hasRetrievable (with ie): ' + hasRetrievable);
            }
            
            // Collect retrievable types
            System.debug('Iterating through metadata objects to find retrievable types...');
            for (Object o : objects) {
                Map<String, Object> m = (Map<String, Object>) o;
                
                String xmlName = (String) m.get('xmlName');
                if (xmlName == null) {
                    System.debug(LoggingLevel.WARN, 'Found a metadata object with a null xmlName. Skipping.');
                    continue;
                }
                
                Boolean include = false;
                
                if (hasRetrieveable) {
                    include = (Boolean) m.get('retrieveable') == true;
                } else if (hasRetrievable) {
                    include = (Boolean) m.get('retrievable') == true;
                } else {
                    include = true; // No flags detected → include all
                }
                
                if (include) {
                    types.add(xmlName);
                }
            }
            
            System.debug('Finished iterating. Total retrievable types found: ' + types.size());
            
            System.debug('Sorting the list of types.');
            types.sort();
            System.debug('TypeaheadSelectionController.getMetadataTypes END');
            return types;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Exception in getMetadataTypes: ' + e.getTypeName() + ' | ' + e.getMessage() + ' | StackTrace: ' + e.getStackTraceString());
            throw new AuraHandledException('Metadata describe failed: ' + e.getMessage());
        }
    }
    
    public class ComponentAgentResult {
        @AuraEnabled public String value;
        @AuraEnabled public String sessionId;
        @AuraEnabled public String rawResponse;
    }
    
}