public with sharing class JiraProcessingService {

    // -----------------------
    // Typed wrapper returned to client JS / LWC / Aura
    // -----------------------
    public class JiraPhaseResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public List<String> storyKeys;
        @AuraEnabled public List<String> subtaskKeys;
        @AuraEnabled public List<String> relatedKeys;
        // attachments: issueKey -> list of ContentVersion Ids (as strings)
        @AuraEnabled public Map<String, List<String>> attachments;
        // AI text result for generateAISolution
        @AuraEnabled public String aiText;

        public JiraPhaseResponse() {
            success = false;
            message = '';
            storyKeys = new List<String>();
            subtaskKeys = new List<String>();
            relatedKeys = new List<String>();
            attachments = new Map<String, List<String>>();
            aiText = '';
        }
    }

    // -----------------------
    // PHASE 1 — processBug
    // Input: single Jira key (bug)
    // Returns: sets of story/subtask/related keys discovered
    // -----------------------
    @AuraEnabled
    public static JiraPhaseResponse processBug(String bugKey) {
        JiraPhaseResponse resp = new JiraPhaseResponse();
        if (String.isBlank(bugKey)) {
            resp.message = 'Missing bugKey';
            return resp;
        }

        try {
            String jql = 'key = ' + bugKey;
            List<Map<String, Object>> issues = JiraSyncUtility.fetchIssues(
                jql,
                new List<String>{ 'summary', 'description', 'issuelinks', 'subtasks', 'issuetype', 'status' }
            );

            // collect next keys into sets and upsert into JIRA_Item__c
            Set<String> storyKeys = new Set<String>();
            Set<String> subtaskKeys = new Set<String>();
            Set<String> relatedKeys = new Set<String>();

            // upsertItems expects (List<Map<String,Object>>, Set<String> nextKeys, Set<String> subtaskKeys)
            JiraSyncUtility.upsertItems(issues, storyKeys, subtaskKeys);

            // Also extract issuelinks explicitly into relatedKeys (if needed)
            for (Map<String,Object> issue : issues) {
                Map<String,Object> fields = (Map<String,Object>) issue.get('fields');
                if (fields != null && fields.containsKey('issuelinks') && fields.get('issuelinks') != null) {
                    for (Object l : (List<Object>) fields.get('issuelinks')) {
                        Map<String,Object> link = (Map<String,Object>) l;
                        if (link.containsKey('inwardIssue')) {
                            relatedKeys.add((String)((Map<String,Object>)link.get('inwardIssue')).get('key'));
                        } else if (link.containsKey('outwardIssue')) {
                            relatedKeys.add((String)((Map<String,Object>)link.get('outwardIssue')).get('key'));
                        }
                    }
                }

                // collect any subtasks also found inline
                if (fields != null && fields.containsKey('subtasks') && fields.get('subtasks') != null) {
                    for (Object s : (List<Object>) fields.get('subtasks')) {
                        subtaskKeys.add((String)((Map<String,Object>)s).get('key'));
                    }
                }
            }

            resp.storyKeys = new List<String>(storyKeys);
            resp.subtaskKeys = new List<String>(subtaskKeys);
            resp.relatedKeys = new List<String>(relatedKeys);
            resp.success = true;
            resp.message = 'Processed bug and upserted item(s).';

        } catch (Exception e) {
            resp.success = false;
            resp.message = 'processBug failed: ' + e.getMessage();
            System.debug('💥 processBug error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        return resp;
    }

    // -----------------------
    // PHASE 2 — processStories
    // Input: list of story keys
    // Returns: discovered related / subtask keys
    // -----------------------
    @AuraEnabled
    public static JiraPhaseResponse processStories(List<String> storyKeysInput) {
        JiraPhaseResponse resp = new JiraPhaseResponse();

        if (storyKeysInput == null || storyKeysInput.isEmpty()) {
            resp.message = 'No story keys provided';
            return resp;
        }

        try {
            Set<String> storyKeys = new Set<String>(storyKeysInput);
            String jql = 'key in (' + String.join(new List<String>(storyKeys), ',') + ')';

            List<Map<String, Object>> stories = JiraSyncUtility.fetchIssues(
                jql,
                new List<String>{ 'summary', 'description', 'issuelinks', 'subtasks', 'issuetype', 'status' }
            );

            Set<String> discoveredRelated = new Set<String>();
            Set<String> discoveredSubtasks = new Set<String>();

            JiraSyncUtility.upsertItems(stories, discoveredRelated, discoveredSubtasks);

            resp.relatedKeys = new List<String>(discoveredRelated);
            resp.subtaskKeys = new List<String>(discoveredSubtasks);
            resp.success = true;
            resp.message = 'Processed stories and upserted JIRA_Item__c records.';

        } catch (Exception e) {
            resp.success = false;
            resp.message = 'processStories failed: ' + e.getMessage();
            System.debug('💥 processStories error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        return resp;
    }

    // -----------------------
    // PHASE 3 — processRelated
    // Input: list of related keys
    // -----------------------
    @AuraEnabled
    public static JiraPhaseResponse processRelated(List<String> relatedKeysInput) {
        JiraPhaseResponse resp = new JiraPhaseResponse();

        if (relatedKeysInput == null || relatedKeysInput.isEmpty()) {
            resp.message = 'No related keys provided';
            return resp;
        }

        try {
            Set<String> relatedKeys = new Set<String>(relatedKeysInput);
            String jql = 'key in (' + String.join(new List<String>(relatedKeys), ',') + ')';

            List<Map<String, Object>> relatedItems = JiraSyncUtility.fetchIssues(
                jql,
                new List<String>{ 'summary', 'description', 'issuelinks', 'subtasks', 'issuetype', 'status' }
            );

            Set<String> discoveredRelated = new Set<String>();
            Set<String> discoveredSubtasks = new Set<String>();

            JiraSyncUtility.upsertItems(relatedItems, discoveredRelated, discoveredSubtasks);

            resp.relatedKeys = new List<String>(discoveredRelated);
            resp.subtaskKeys = new List<String>(discoveredSubtasks);
            resp.success = true;
            resp.message = 'Processed related items and upserted JIRA_Item__c records.';

        } catch (Exception e) {
            resp.success = false;
            resp.message = 'processRelated failed: ' + e.getMessage();
            System.debug('💥 processRelated error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return resp;
    }

    // -----------------------
    // PHASE 4 — processSubtasks
    // Input: list of subtask keys
    // -----------------------
    @AuraEnabled
    public static JiraPhaseResponse processSubtasks(List<String> subtaskKeysInput) {
        JiraPhaseResponse resp = new JiraPhaseResponse();

        if (subtaskKeysInput == null || subtaskKeysInput.isEmpty()) {
            resp.message = 'No subtask keys provided';
            return resp;
        }

        try {
            Set<String> subtaskKeys = new Set<String>(subtaskKeysInput);
            String jql = 'key in (' + String.join(new List<String>(subtaskKeys), ',') + ')';

            List<Map<String, Object>> subtasks = JiraSyncUtility.fetchIssues(
                jql,
                new List<String>{ 'summary', 'description', 'issuetype', 'status' }
            );

            Set<String> dummyRelated = new Set<String>();
            Set<String> discoveredSubtasks = new Set<String>();

            JiraSyncUtility.upsertItems(subtasks, dummyRelated, discoveredSubtasks);

            resp.subtaskKeys = new List<String>(discoveredSubtasks);
            resp.success = true;
            resp.message = 'Processed subtasks and upserted JIRA_Item__c records.';

        } catch (Exception e) {
            resp.success = false;
            resp.message = 'processSubtasks failed: ' + e.getMessage();
            System.debug('💥 processSubtasks error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return resp;
    }

    // -----------------------
    // PHASE 5 — buildContext
    // Input: map of bugKey -> list of related entity keys (stories, subtasks, related)
    // This calls JiraSyncUtility.buildAndUpdateContext which updates JIRA_Item__c.Context__c
    // -----------------------
    @AuraEnabled
    public static JiraPhaseResponse buildContext(Map<String, List<String>> bugToEntities) {
        JiraPhaseResponse resp = new JiraPhaseResponse();

        if (bugToEntities == null || bugToEntities.isEmpty()) {
            resp.message = 'No bugToEntities map provided';
            return resp;
        }

        try {
            JiraSyncUtility.buildAndUpdateContext(bugToEntities);
            resp.success = true;
            resp.message = 'Context built and updated for provided bugs.';
        } catch (Exception e) {
            resp.success = false;
            resp.message = 'buildContext failed: ' + e.getMessage();
            System.debug('💥 buildContext error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return resp;
    }

    // -----------------------
    // PHASE 6 — fetchAttachments
    // Input:
    //   - bugToEntities: map of bug -> list of related keys
    //   - bugKey (optional): if provided, only process attachments for that bug's entity list (recommended)
    // Returns attachments as Map<String, List<String>> where keys are issue keys and values are ContentVersion Id strings
    // -----------------------
    @AuraEnabled
    public static JiraPhaseResponse fetchAttachments(Map<String, List<String>> bugToEntities, String bugKey) {
        JiraPhaseResponse resp = new JiraPhaseResponse();

        if (bugToEntities == null || bugToEntities.isEmpty()) {
            resp.message = 'No bugToEntities provided';
            return resp;
        }

        try {
            // If bugKey provided, only process that one
            List<String> keysToProcess = new List<String>();
            if (!String.isBlank(bugKey)) {
                if (!bugToEntities.containsKey(bugKey)) {
                    resp.message = 'bugKey not found in bugToEntities';
                    return resp;
                }
                keysToProcess.add(bugKey);
            } else {
                keysToProcess.addAll(bugToEntities.keySet());
            }

            Map<String, List<String>> attachmentsResult = new Map<String, List<String>>();

            for (String bk : keysToProcess) {
                List<String> related = bugToEntities.get(bk);
                if (related == null) related = new List<String>();
                if (!related.contains(bk)) related.add(bk);

                Set<String> allKeys = new Set<String>(related);
                // call JiraSyncUtility.fetchAndAttachFilesForIssues(bugKey, Set<String>)
                Map<String, List<Id>> fetched = JiraSyncUtility.fetchAndAttachFilesForIssues(bk, allKeys);

                // convert Ids to Strings for wrapper
                for (String issueKey : fetched.keySet()) {
                    List<Id> ids = fetched.get(issueKey);
                    List<String> idStrings = new List<String>();
                    for (Id i : ids) idStrings.add(String.valueOf(i));
                    attachmentsResult.put(issueKey, idStrings);
                }
            }

            resp.attachments = attachmentsResult;
            resp.success = true;
            resp.message = 'Attachments fetched/linked successfully.';

        } catch (Exception e) {
            resp.success = false;
            resp.message = 'fetchAttachments failed: ' + e.getMessage();
            System.debug('💥 fetchAttachments error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return resp;
    }

    // -----------------------
    // PHASE 7 — generateAISolution
    // Input: single bugKey — finds JIRA_Item__c, calls prompt template, writes AIGeneratedSolution__c
    // -----------------------
    @AuraEnabled
    public static JiraPhaseResponse generateAISolution(String bugKey) {
        JiraPhaseResponse resp = new JiraPhaseResponse();

        if (String.isBlank(bugKey)) {
            resp.message = 'Missing bugKey';
            return resp;
        }

        try {
            // fetch the JIRA_Item__c record
            List<JIRA_Item__c> items = [
                SELECT Id, JIRAKey__c, Context__c, Description__c, Name, AIGeneratedSolution__c
                FROM JIRA_Item__c
                WHERE JIRAKey__c = :bugKey
                LIMIT 1
            ];

            if (items.isEmpty()) {
                resp.message = 'No JIRA_Item__c found for key ' + bugKey;
                return resp;
            }

            JIRA_Item__c item = items[0];

            // if solution already present, return it
            if (String.isNotBlank(item.AIGeneratedSolution__c)) {
                resp.success = true;
                resp.aiText = item.AIGeneratedSolution__c;
                resp.message = 'AI solution already exists for ' + bugKey;
                return resp;
            }

            // Build input wrapper for Prompt Template
            Map<String, String> wrapper = new Map<String, String>{ 'id' => String.valueOf(item.Id) };
            ConnectApi.WrappedValue itemValue = new ConnectApi.WrappedValue();
            itemValue.value = wrapper;

            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            inputParams.put('Input:JIRAItem', itemValue);

            ConnectApi.EinsteinPromptTemplateGenerationsInput templateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            templateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            templateInput.additionalConfig.applicationName = 'JIRA_AI_Solution_Generator';
            templateInput.isPreview = false;
            templateInput.inputParams = inputParams;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('JIRA_Solution_Generator', templateInput);

            String aiText = (result != null && result.generations != null && !result.generations.isEmpty())
                ? result.generations[0].text
                : null;

            if (String.isBlank(aiText)) {
                resp.success = false;
                resp.message = 'AI did not return any text';
                return resp;
            }

            // Update record
            item.AIGeneratedSolution__c = aiText;
            update item;

            resp.success = true;
            resp.aiText = aiText;
            resp.message = 'AI solution generated and saved for ' + bugKey;

        } catch (Exception e) {
            resp.success = false;
            resp.message = 'generateAISolution failed: ' + e.getMessage();
            System.debug('💥 generateAISolution error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return resp;
    }
}