/**
 * @description Unit tests for Opportunity rollup (trigger + service + invocable).
 * Covers inserts, relinks, bulk operations, zero-case, and invocable usage.
 */
@IsTest
private class OpportunityAccountRollupService_Tests {
    @TestSetup
    static void setupData() {
        List<Account> accts = new List<Account>{
            new Account(Name = 'Acct A'),
            new Account(Name = 'Acct B'),
            new Account(Name = 'Acct C')
        };
        insert accts;
    }

    @IsTest
    static void testInsertCountsSingle() {
        Account a = [SELECT Id, Opportunity_Count__c FROM Account WHERE Name = 'Acct A' WITH SECURITY_ENFORCED LIMIT 1];
        System.assertEquals(null, a.Opportunity_Count__c, 'Precondition: field default should be null prior to any opps');

        Opportunity o = new Opportunity(Name = 'Opp 1', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), AccountId = a.Id);
        Test.startTest();
        insert o;
        Test.stopTest();

        Account aAfter = [SELECT Id, Opportunity_Count__c FROM Account WHERE Id = :a.Id WITH SECURITY_ENFORCED LIMIT 1];
        System.assertEquals(1, (Integer)aAfter.Opportunity_Count__c, 'Account should reflect 1 opportunity');
    }

    @IsTest
    static void testInsertCountsBulk() {
        List<Account> accts = [SELECT Id, Name FROM Account WHERE Name IN ('Acct A','Acct B') WITH SECURITY_ENFORCED];
        Id aId = accts[0].Name == 'Acct A' ? accts[0].Id : accts[1].Id;
        Id bId = accts[0].Name == 'Acct B' ? accts[0].Id : accts[1].Id;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 50; i++) {
            opps.add(new Opportunity(Name = 'Opp A ' + i, StageName = 'Prospecting', CloseDate = Date.today(), AccountId = aId));
        }
        for (Integer j = 0; j < 75; j++) {
            opps.add(new Opportunity(Name = 'Opp B ' + j, StageName = 'Prospecting', CloseDate = Date.today(), AccountId = bId));
        }

        Test.startTest();
        insert opps;
        Test.stopTest();

        Map<Id, Account> afterMap = new Map<Id, Account>([
            SELECT Id, Opportunity_Count__c FROM Account WHERE Id IN :new Set<Id>{aId, bId} WITH SECURITY_ENFORCED
        ]);
        System.assertEquals(50, (Integer)afterMap.get(aId).Opportunity_Count__c, 'Acct A should have 50 opps');
        System.assertEquals(75, (Integer)afterMap.get(bId).Opportunity_Count__c, 'Acct B should have 75 opps');
    }

    @IsTest
    static void testRelinkBetweenAccounts() {
        List<Account> accts = [SELECT Id, Name FROM Account WHERE Name IN ('Acct A','Acct B') WITH SECURITY_ENFORCED];
        Id aId = accts[0].Name == 'Acct A' ? accts[0].Id : accts[1].Id;
        Id bId = accts[0].Name == 'Acct B' ? accts[0].Id : accts[1].Id;

        Opportunity o = new Opportunity(Name='Opp Relink', StageName='Prospecting', CloseDate=Date.today(), AccountId=aId);
        insert o;

        // Verify A is 1
        Account a1 = [SELECT Id, Opportunity_Count__c FROM Account WHERE Id = :aId WITH SECURITY_ENFORCED];
        System.assertEquals(1, (Integer)a1.Opportunity_Count__c);

        // Relink to B
        Test.startTest();
        o = [SELECT Id, AccountId FROM Opportunity WHERE Id = :o.Id WITH SECURITY_ENFORCED];
        o.AccountId = bId;
        update o;
        Test.stopTest();

        // Now A should be 0, B should be 1
        Map<Id, Account> after = new Map<Id, Account>([
            SELECT Id, Opportunity_Count__c FROM Account WHERE Id IN :new Set<Id>{aId, bId} WITH SECURITY_ENFORCED
        ]);
        System.assertEquals(0, (Integer)after.get(aId).Opportunity_Count__c, 'Acct A should have 0 after relink');
        System.assertEquals(1, (Integer)after.get(bId).Opportunity_Count__c, 'Acct B should have 1 after relink');
    }

    @IsTest
    static void testZeroCase() {
        Account c = [SELECT Id FROM Account WHERE Name = 'Acct C' WITH SECURITY_ENFORCED LIMIT 1];
        // Ensure there are no opps for C, force recalculation via invocable
        OpportunityAccountRollupInvocable.Request r = new OpportunityAccountRollupInvocable.Request();
        r.accountId = c.Id;

        Test.startTest();
        OpportunityAccountRollupInvocable.recalc(new List<OpportunityAccountRollupInvocable.Request>{ r });
        Test.stopTest();

        Account cAfter = [SELECT Id, Opportunity_Count__c FROM Account WHERE Id = :c.Id WITH SECURITY_ENFORCED];
        System.assertEquals(0, (Integer)cAfter.Opportunity_Count__c, 'Account with no opps should be 0');
    }

    @IsTest
    static void testBulkRelink200() {
        Account a = [SELECT Id FROM Account WHERE Name = 'Acct A' WITH SECURITY_ENFORCED LIMIT 1];
        Account b = [SELECT Id FROM Account WHERE Name = 'Acct B' WITH SECURITY_ENFORCED LIMIT 1];

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(Name='Bulk Opp ' + i, StageName='Prospecting', CloseDate=Date.today(), AccountId=a.Id));
        }
        insert opps;

        // Now relink all to B
        for (Opportunity o : opps) {
            o.AccountId = b.Id;
        }
        Test.startTest();
        update opps;
        Test.stopTest();

        Map<Id, Account> after = new Map<Id, Account>([
            SELECT Id, Opportunity_Count__c FROM Account WHERE Id IN :new Set<Id>{a.Id, b.Id} WITH SECURITY_ENFORCED
        ]);
        System.assertEquals(0, (Integer)after.get(a.Id).Opportunity_Count__c, 'Acct A should be 0 after moving 200 opps out');
        System.assertEquals(200, (Integer)after.get(b.Id).Opportunity_Count__c, 'Acct B should be 200 after receiving 200 opps');
    }
}
