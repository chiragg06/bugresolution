public without sharing class TypeaheadSelectionController {
    
    @AuraEnabled(cacheable = true)
    public static List<Object> getTypeAheadResults(String searchedValue, String selectedPill) {
        if(selectedPill == ''){
            
        }
        else if(selectedPill == ''){
            
        }
        else if(selectedPill == ''){
            
        }
        Map<String, Object> inputMap = new Map<String, Object>();
        inputMap.put('componentName', searchedValue);
        inputMap.put('componentType', selectedPill);
        
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
                    
                    if (validPills.contains(selectedPill)) {
                        String methodName = 'get' + selectedPill + 's';
                        helper.invokeMethod(methodName, inputMap, outputMap, options);
                    }
        
        
        if (outputMap.containsKey('success') && outputMap.get('success') == false) {
            throw new AuraHandledException('Error occurred while fetching data: ' + outputMap.get('error'));
        }
        
        // Ensure that the output from the helper is always a List before casting.
        // The helper methods are modified below to guarantee this.
        Object rawResult = outputMap.get(selectedPill + 's');
        if (rawResult instanceof List<Object>) {
            return (List<Object>) rawResult;
        } else {
            System.debug('Unexpected return type from TypeaheadServiceHelper for ' + selectedPill + 's: ' + rawResult);
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
        ComponentAgentResult result = new ComponentAgentResult();
        
        try {
            String userMessage =
                'Retrieve the component details of type \'' + componentType +
                '\' for component \'' + componentName +
                '\' with ID \'' + componentId + '\'';
            
            Invocable.Action action = Invocable.Action.createCustomAction(
                'generateAiAgentResponse',
                'ComponentKnowledgeAgent'
            );
            
            action.setInvocationParameter('userMessage', userMessage);
            
            if (sessionId != null) {
                action.setInvocationParameter('sessionId', sessionId);
            }
            
            List<Invocable.Action.Result> results = action.invoke();
            System.debug('Checking agent results. Is the results list empty? ' + results.isEmpty());
            
            if (!results.isEmpty()) {
                Map<String, Object> outputParams = results[0].getOutputParameters();
                System.debug('Full Agent Output Parameters: ' + JSON.serialize(outputParams));
                
                if (outputParams.containsKey('agentResponse')) {
                    String jsonStr = (String) outputParams.get('agentResponse');
                    System.debug('Raw agentResponse JSON String: ' + jsonStr);
                    
                    Map<String, Object> parsed =
                        (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
                    	System.debug('Parsed agentResponse Map: ' + JSON.serializePretty(parsed));
                    
                    result.value = (String) parsed.get('value');
                    result.sessionId =
                        (String) parsed.get('sessionId');
                    System.debug('Extracted Result Value: ' + result.value);
                    System.debug('Extracted Session ID: ' + result.sessionId);
                    
                    result.rawResponse = jsonStr;
                    return result;
                }
            }
            
            result.value = 'No response from Agent';
            return result;
            
        } catch (Exception e) {
            result.value = 'Error: ' + e.getMessage();
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
            
            // -------------------------------------------------------------
            // 🟣 Invoke Agent
            // -------------------------------------------------------------
            Invocable.Action action = Invocable.Action.createCustomAction(
                'generateAiAgentResponse',
                'ComponentKnowledgeAgent'
            );
            
            action.setInvocationParameter('userMessage', userMessage);
            
            // Only pass session ID if available
            if (sessionId != null) {
                action.setInvocationParameter('sessionId', sessionId);
            }
            
            List<Invocable.Action.Result> results = action.invoke();
            
            if (!results.isEmpty()) {
                
                Map<String, Object> params = results[0].getOutputParameters();
                
                if (params.containsKey('agentResponse')) {
                    
                    String jsonStr = (String) params.get('agentResponse');
                    
                    Map<String, Object> parsed =
                        (Map<String, Object>) JSON.deserializeUntyped(jsonStr);
                    
                    result.value = (String) parsed.get('value');
                    result.sessionId = (String) parsed.get('sessionId');
                    result.rawResponse = jsonStr;
                    
                    return result;
                }
            }
            
            result.value = 'No response from Agent.';
            return result;
            
        } catch (Exception e) {
            result.value = 'Error removing component: ' + e.getMessage();
            return result;
        }
    }
    
   @AuraEnabled
    public static List<String> getMetadataTypes() {
        
        List<String> types = new List<String>();
        
        try {
            // Instantiate Metadata API service using Named Credential
            MetadataService.MetadataPort svc = new MetadataService.MetadataPort();
            
            // Override endpoint to use Named Credential (ApexMDAPI)
            svc.endpoint_x = 'callout:MetadataAPI/services/Soap/m/61.0';
            
            // Use OAuth token provided by Named Credential
            svc.SessionHeader = new MetadataService.SessionHeader_element();
            svc.SessionHeader.sessionId = '{!$Credential.OAuthToken}';
            
            // Call describeMetadata
            MetadataService.DescribeMetadataResult dm = svc.describeMetadata(61.0D);
            
            // JSON workaround to avoid retrievable / retrieveable variations
            String jsonText = JSON.serialize(dm.metadataObjects);
            List<Object> objects = (List<Object>) JSON.deserializeUntyped(jsonText);
            
            Boolean hasRetrieveable = false;
            Boolean hasRetrievable = false;
            
            if (!objects.isEmpty()) {
                Map<String, Object> first = (Map<String, Object>) objects[0];
                hasRetrieveable = first.containsKey('retrieveable');
                hasRetrievable  = first.containsKey('retrievable');
            }
            
            // Collect retrievable types
            for (Object o : objects) {
                Map<String, Object> m = (Map<String, Object>) o;
                
                String xmlName = (String) m.get('xmlName');
                if (xmlName == null) continue;
                
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
            
            types.sort();
            return types;
            
        } catch (Exception e) {
            throw new AuraHandledException('Metadata describe failed: ' + e.getMessage());
        }
    }
    
    public class ComponentAgentResult {
        @AuraEnabled public String value;
        @AuraEnabled public String sessionId;
        @AuraEnabled public String rawResponse;
    }
    
}