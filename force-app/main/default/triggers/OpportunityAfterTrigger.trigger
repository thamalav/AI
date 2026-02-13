trigger OpportunityAfterTrigger on Opportunity (after insert, after update) {
    if (Trigger.isAfter) {
        // after update
        OpportunityTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap);
    }
}
