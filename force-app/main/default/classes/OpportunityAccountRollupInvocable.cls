/**
 * @description Invocable Apex to recalc Account.Opportunity_Count__c for provided Accounts.
 * Enables Flow or Admin-driven recalculation on demand.
 */
public with sharing class OpportunityAccountRollupInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id accountId;
    }
    public class Response {
        @InvocableVariable
        public Id accountId;
        @InvocableVariable
        public String status;
        @InvocableVariable
        public String message;
    }

    /**
     * @description Invocable method to recalc counts for a list of Account Ids.
     */
    @InvocableMethod(label='Recalculate Opportunity Count for Accounts' description='Recalculate Account.Opportunity_Count__c for provided Account Ids')
    public static List<Response> recalc(List<Request> requests) {
        List<Response> results = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }
        Set<Id> accountIds = new Set<Id>();
        for (Request r : requests) {
            if (r != null && r.accountId != null) {
                accountIds.add(r.accountId);
            }
        }
        if (!accountIds.isEmpty()) {
            try {
                OpportunityAccountRollupService.recalcAccountOpportunityCounts(accountIds);
                for (Id aId : accountIds) {
                    Response resp = new Response();
                    resp.accountId = aId;
                    resp.status = 'SUCCESS';
                    results.add(resp);
                }
            } catch (Exception e) {
                for (Id aId : accountIds) {
                    Response resp = new Response();
                    resp.accountId = aId;
                    resp.status = 'ERROR';
                    resp.message = e.getMessage();
                    results.add(resp);
                }
            }
        }
        return results;
    }
}
