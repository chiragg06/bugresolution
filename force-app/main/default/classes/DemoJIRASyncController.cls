public with sharing class DemoJIRASyncController 
{
    @AuraEnabled
    public static Object exchangeAuthorizationCode(String code) {
        String clientId = 'wTCk7CcKzhvLGgwXA7qOq5CovQcGXkKo'; 
        String clientSecret = 'ATOAcnm7n6Wng3_oBYJWIf4zHOwEItl0EvWqtztDz1eOJG9XkQUPYWJltp6-txc-faGCB6122B17'; 
        String redirectUri = 'https://pr1733992221355--poc.sandbox.my.site.com/resolutionOnDemand/s/get-started'; 
        
        String tokenUrl = 'https://auth.atlassian.com/oauth/token';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        String jsonBody = JSON.serialize(new Map<String, String>{
            'grant_type' => 'authorization_code',
            'client_id' => clientId,
            'client_secret' => clientSecret,
            'code' => code,
            'redirect_uri' => redirectUri
        });

        req.setBody(jsonBody);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return JSON.deserializeUntyped(res.getBody());
        } else {
            throw new AuraHandledException('Error exchanging authorization code. '+res.getBody());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> checkTokenValidity(String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.atlassian.com/oauth/token/accessible-resources');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/json');
        
        Map<String, Object> response = new Map<String, Object>();
        
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Token is valid
                response.put('isValid', true);
                response.put('errorMessage', null);
                response.put('resources', JSON.deserializeUntyped(res.getBody()));
            } else {
                // Handle non-200 responses
                response.put('isValid', false);
                response.put('errorMessage', 'Invalid token: ' + res.getBody());
            }
        } catch (Exception e) {
            // Handle errors
            response.put('isValid', false);
            response.put('errorMessage', 'Error: ' + e.getMessage());
        }

        return response;
    }

    @AuraEnabled
    public static Map<String, Object> getUserDetails(String accessToken, String jiraCloudId) {
        System.debug('accesstoken: '+accessToken);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.atlassian.com/ex/jira/' + jiraCloudId + '/rest/api/3/myself');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            throw new AuraHandledException('Error fetching user details: ' + res.getStatus());
        }
    }

    // Method to get all projects
    @AuraEnabled
    public static Object getProjects(String accessToken, String jiraCloudId) {
        System.debug('accesstoken: '+accessToken);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.atlassian.com/ex/jira/' + jiraCloudId + '/rest/api/3/project');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            System.debug('Pojrects--->: '+res.getBody());
            return JSON.deserializeUntyped(res.getBody());
        } else {
            throw new AuraHandledException('Error fetching projects: ' + res.getStatus());
        }
    }

    // Method to get boards for a project
    @AuraEnabled
    public static Object getBoards(String accessToken, String jiraCloudId, String projectKeyOrId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.atlassian.com/ex/jira/' + jiraCloudId + '/rest/agile/1.0/board?projectKeyOrId=' + projectKeyOrId);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return JSON.deserializeUntyped(res.getBody());
        } else {
            throw new AuraHandledException('Error fetching boards: ' + res.getStatus());
        }
    }

    // Method to get sprints for a board
    @AuraEnabled
    public static Object getSprints(String accessToken, String jiraCloudId, String boardId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.atlassian.com/ex/jira/' + jiraCloudId + '/rest/agile/1.0/board/' + boardId + '/sprint');
        // req.setEndpoint('https://api.atlassian.com/ex/jira/' + jiraCloudId + '/rest/api/3/search');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Accept', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return JSON.deserializeUntyped(res.getBody());
        } else {
            throw new AuraHandledException('Error fetching sprints: ' + res.getStatus());
        }
    }

    @AuraEnabled
    public static Object getBugsForSprint(String accessToken, String jiraCloudId, String sprintId) {
        System.debug('accessToken'+accessToken+ ' jiraCloudID: '+ jiraCloudId + ' sprintId: '+sprintId);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.atlassian.com/ex/jira/' + jiraCloudId + '/rest/api/3/search/jql');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json'); // Set the content type to JSON

        String jqlQuery = 'sprint=' + sprintId + ' AND issuetype=Bug';
        String requestBody = JSON.serialize(new Map<String, String>{
            'jql' => jqlQuery,
            'expand'=> 'renderedFields,names,schema'
        });
        req.setBody(requestBody);

        Http http = new Http();
        HttpResponse res = http.send(req);
         System.debug('response'+res.getBody());

        if (res.getStatusCode() == 200) {
            return JSON.deserializeUntyped(res.getBody());
        } else {
            throw new AuraHandledException('Error fetching bugs: ' + res.getStatus() + ' ' + res.getBody());
        }
    }
    
    
       /* @AuraEnabled
public static Object getBugsForSprint(String accessToken, String jiraCloudId, String sprintId) {
    HttpRequest req = new HttpRequest();
    // CORRECTION: Removed '/jql' from the end of the URL
    req.setEndpoint('https://api.atlassian.com/ex/jira/' + jiraCloudId + '/rest/api/3/search');
    req.setMethod('POST');
    req.setHeader('Authorization', 'Bearer ' + accessToken);
    req.setHeader('Content-Type', 'application/json');

    // Ensure sprintId is a number/string. 
    // Note: If 'Bug' is not the exact name of the issue type in your Jira, change it (e.g., 'Defect').
    String jqlQuery = 'sprint=' + sprintId + ' AND issuetype=Bug';
    
    String requestBody = JSON.serialize(new Map<String, String>{
        'jql' => jqlQuery,
        'fields' => 'summary,description,priority,status' // Optional: Limit fields to make response cleaner
    });
    req.setBody(requestBody);

    Http http = new Http();
    HttpResponse res = http.send(req);

    if (res.getStatusCode() == 200) {
        return JSON.deserializeUntyped(res.getBody());
    } else {
        // Helpful debug logging
        System.debug('Jira Search Error: ' + res.getBody()); 
        throw new AuraHandledException('Error fetching bugs: ' + res.getStatus() + ' ' + res.getBody());
    }
} */

}