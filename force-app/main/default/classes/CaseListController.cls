public with sharing class CaseListController {
    public class PageResult {
        @AuraEnabled public List<Case> records;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer totalPages;
    }

    @AuraEnabled(cacheable=true)
    public static PageResult searchCases(String searchText, Integer pageNumber, Integer pageSize) {
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize   == null || pageSize   < 1) pageSize   = 25;

        String q = String.valueOf(searchText == null ? '' : searchText).trim();
        // Simple filter: match subject or case number
        String likel = '%' + q.replace('%','\\%').replace('_','\\_') + '%';

        // total count
        Integer totalCount = (q == '')
            ? [SELECT count() FROM Case]
            : [SELECT count() FROM Case WHERE Subject LIKE :likel OR CaseNumber LIKE :likel];

        Integer offsetRows = (pageNumber - 1) * pageSize;

        List<Case> rows = (q == '')
            ? [SELECT Id, CaseNumber, Subject, Status, Priority, Owner.Name, CreatedDate
               FROM Case
               ORDER BY CreatedDate DESC
               LIMIT :pageSize OFFSET :offsetRows]
            : [SELECT Id, CaseNumber, Subject, Status, Priority, Owner.Name, CreatedDate
               FROM Case
               WHERE Subject LIKE :likel OR CaseNumber LIKE :likel
               ORDER BY CreatedDate DESC
               LIMIT :pageSize OFFSET :offsetRows];

        PageResult pr = new PageResult();
        pr.records    = rows;
        pr.pageNumber = pageNumber;
        pr.pageSize   = pageSize;
        pr.totalCount = totalCount;
        pr.totalPages = (Integer)Math.ceil((Decimal)totalCount / pageSize);
        return pr;
    }
}
