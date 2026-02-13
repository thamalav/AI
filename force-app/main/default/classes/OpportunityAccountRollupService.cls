/**
 * @description Service to recalculate and persist Account.Opportunity_Count__c.
 * Implements bulk, user-mode DML, and WITH SECURITY_ENFORCED per org standards.
 */
public with sharing class OpportunityAccountRollupService {
    /**
     * @description Recalculate counts for provided Account Ids.
     * Counts ALL Opportunities related to each Account.
     * Uses user-mode DML and WITH SECURITY_ENFORCED for SOQL.
     */
    public static void recalcAccountOpportunityCounts(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return; // Return early
        }

        // Aggregate counts by AccountId
        Map<Id, Integer> acctIdToCount = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT AccountId accId, COUNT(Id) cnt
            FROM Opportunity
            WHERE AccountId IN :accountIds
            WITH SECURITY_ENFORCED
            GROUP BY AccountId
        ]) {
            acctIdToCount.put((Id) ar.get('accId'), (Integer) ar.get('cnt'));
        }

        // Prepare Account updates
        List<Account> updates = new List<Account>();
        for (Id acctId : accountIds) {
            Integer c = acctIdToCount.containsKey(acctId) ? acctIdToCount.get(acctId) : 0;
            Account a = new Account(Id = acctId);
            a.Opportunity_Count__c = c;
            updates.add(a);
        }
        if (!updates.isEmpty()) {
            Database.SaveResult[] results = Database.update(
                updates,
                new Database.DMLOptions(AccessLevel = Database.AccessLevel.USER_MODE)
            );
            // Optional: collect failures for logging/monitoring (no System.debug in prod code)
            // Intentionally not throwing to avoid partial success loss in triggers
        }
    }
}
