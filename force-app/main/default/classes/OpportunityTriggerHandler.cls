/**
 * @description Trigger handler for Opportunity after events.
 * Bulkified logic to recalc Account.Opportunity_Count__c when Opps are created
 * or relinked between Accounts.
 * 
 * Design:
 * - after insert: count new.AccountId
 * - after update: when AccountId changed, count both old and new AccountId
 * - Delegates to OpportunityAccountRollupService for aggregation/DML
 */
public with sharing class OpportunityTriggerHandler {
    /**
     * @description Entry point for after trigger contexts.
     */
    public static void handleAfter(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        if (newList == null || newList.isEmpty()) {
            return;
        }
        // Collect impacted Account Ids: new and old (for relinks)
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : newList) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
        }
        if (oldMap != null && !oldMap.isEmpty()) {
            for (Opportunity opp : newList) {
                Opportunity oldOpp = oldMap.get(opp.Id);
                if (oldOpp == null) {
                    continue;
                }
                // If AccountId changed, add old and new
                if (opp.AccountId != oldOpp.AccountId) {
                    if (oldOpp.AccountId != null) {
                        accountIds.add(oldOpp.AccountId);
                    }
                    if (opp.AccountId != null) {
                        accountIds.add(opp.AccountId);
                    }
                }
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }
        OpportunityAccountRollupService.recalcAccountOpportunityCounts(accountIds);
    }
}
