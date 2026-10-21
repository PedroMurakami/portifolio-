/**
 * @description Comprehensive test class for the Helpdesk Ticket feature.
 *              Covers: Trigger → Handler → Service → Controller.
 *              Targets > 95 % code coverage with positive, negative and bulk scenarios.
 * @author      Portfolio Project
 */
@isTest
private class HelpdeskTicketTest {

    /* ═══════════════════════════════════════════════════════════
     *  SERVICE / TRIGGER TESTS
     * ═══════════════════════════════════════════════════════════ */

    @isTest
    static void testInsertSetsDefaultsAndSla() {
        // Arrange — ticket with explicit priority, no status
        Helpdesk_Ticket__c t = new Helpdesk_Ticket__c(
            Title__c    = 'Login issue',
            Priority__c = 'High'
        );

        // Act
        Test.startTest();
        insert t;
        Test.stopTest();

        // Assert
        t = [SELECT Status__c, SLA_Deadline__c FROM Helpdesk_Ticket__c WHERE Id = :t.Id];
        System.assertEquals('High', [SELECT Priority__c FROM Helpdesk_Ticket__c WHERE Id = :t.Id].Priority__c,
            'Priority should remain High.');
        System.assertNotEquals(null, t.SLA_Deadline__c,
            'SLA_Deadline__c must be populated on insert.');
    }

    @isTest
    static void testInsertCriticalSlaDeadline() {
        DateTime before = DateTime.now();

        Test.startTest();
        Helpdesk_Ticket__c t = new Helpdesk_Ticket__c(
            Title__c    = 'Server down',
            Priority__c = 'Critical',
            Status__c   = 'New'
        );
        insert t;
        Test.stopTest();

        t = [SELECT SLA_Deadline__c FROM Helpdesk_Ticket__c WHERE Id = :t.Id];
        // Critical = 4 hours. Deadline should be between now+4h-1min and now+4h+1min (clock tolerance).
        DateTime expectedMin = before.addHours(4).addMinutes(-1);
        DateTime expectedMax = before.addHours(4).addMinutes(1);
        System.assert(t.SLA_Deadline__c >= expectedMin && t.SLA_Deadline__c <= expectedMax,
            'Critical SLA deadline should be ~4 hours from now. Got: ' + t.SLA_Deadline__c);
    }

    @isTest
    static void testPriorityChangeRecalculatesSla() {
        Helpdesk_Ticket__c t = TestDataFactory.createAndInsertTickets(1, 'Low', 'New')[0];
        DateTime originalDeadline = [SELECT SLA_Deadline__c FROM Helpdesk_Ticket__c WHERE Id = :t.Id].SLA_Deadline__c;

        Test.startTest();
        t.Priority__c = 'Critical';
        update t;
        Test.stopTest();

        DateTime newDeadline = [SELECT SLA_Deadline__c FROM Helpdesk_Ticket__c WHERE Id = :t.Id].SLA_Deadline__c;
        System.assert(newDeadline < originalDeadline,
            'Changing priority from Low (72 h) to Critical (4 h) should shorten the deadline.');
    }

    @isTest
    static void testSlaViolationFlagOnUpdate() {
        // Insert a ticket and manually set a past deadline via direct field update.
        Helpdesk_Ticket__c t = new Helpdesk_Ticket__c(
            Title__c    = 'Expired ticket',
            Priority__c = 'Medium',
            Status__c   = 'New'
        );
        insert t;

        // Force SLA_Deadline__c into the past (bypass trigger by using direct update path).
        t.SLA_Deadline__c = DateTime.now().addHours(-1);
        // We need a field change that fires the trigger — change Title to force before update.
        t.Title__c = 'Expired ticket — updated';
        Test.startTest();
        update t;
        Test.stopTest();

        t = [SELECT SLA_Violated__c FROM Helpdesk_Ticket__c WHERE Id = :t.Id];
        System.assertEquals(true, t.SLA_Violated__c,
            'Ticket with a past SLA_Deadline__c and non-resolved status should be marked violated.');
    }

    @isTest
    static void testResolvedTicketNotFlaggedAsViolated() {
        Helpdesk_Ticket__c t = new Helpdesk_Ticket__c(
            Title__c    = 'Resolved before deadline',
            Priority__c = 'Medium',
            Status__c   = 'New'
        );
        insert t;

        // Set deadline in the past BUT resolve the ticket.
        t.SLA_Deadline__c = DateTime.now().addHours(-2);
        t.Status__c       = 'Resolved';
        Test.startTest();
        update t;
        Test.stopTest();

        t = [SELECT SLA_Violated__c FROM Helpdesk_Ticket__c WHERE Id = :t.Id];
        System.assertEquals(false, t.SLA_Violated__c,
            'Resolved tickets should NOT be flagged as SLA violated.');
    }

    /* ═══════════════════════════════════════════════════════════
     *  BULK TEST (200+ records)
     * ═══════════════════════════════════════════════════════════ */

    @isTest
    static void testBulkInsert200Records() {
        List<Helpdesk_Ticket__c> tickets = TestDataFactory.createTickets(200, 'High', 'New');

        Test.startTest();
        insert tickets;
        Test.stopTest();

        List<Helpdesk_Ticket__c> inserted = [
            SELECT SLA_Deadline__c, Status__c
            FROM Helpdesk_Ticket__c
            WHERE Id IN :tickets
        ];
        System.assertEquals(200, inserted.size(), 'All 200 records must be inserted.');
        for (Helpdesk_Ticket__c t : inserted) {
            System.assertNotEquals(null, t.SLA_Deadline__c, 'Every record must have an SLA deadline.');
        }
    }

    @isTest
    static void testBulkUpdate200Records() {
        List<Helpdesk_Ticket__c> tickets = TestDataFactory.createAndInsertTickets(200, 'Low', 'New');

        for (Helpdesk_Ticket__c t : tickets) {
            t.Priority__c = 'Critical';
        }

        Test.startTest();
        update tickets;
        Test.stopTest();

        List<Helpdesk_Ticket__c> updated = [
            SELECT SLA_Deadline__c FROM Helpdesk_Ticket__c WHERE Id IN :tickets
        ];
        System.assertEquals(200, updated.size(), 'All 200 updated records should be queryable.');
    }

    /* ═══════════════════════════════════════════════════════════
     *  CONTROLLER TESTS
     * ═══════════════════════════════════════════════════════════ */

    @isTest
    static void testGetTicketsNoFilters() {
        TestDataFactory.createAndInsertTickets(5, 'Medium', 'New');

        Test.startTest();
        List<Helpdesk_Ticket__c> results = HelpdeskTicketController.getTickets(null, null, null);
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Should return all 5 tickets when no filters applied.');
    }

    @isTest
    static void testGetTicketsWithSearchTerm() {
        TestDataFactory.createAndInsertTickets(3, 'High', 'New');
        Helpdesk_Ticket__c special = new Helpdesk_Ticket__c(
            Title__c    = 'VPN Connection Failure',
            Priority__c = 'Critical',
            Status__c   = 'New'
        );
        insert special;

        Test.startTest();
        List<Helpdesk_Ticket__c> results = HelpdeskTicketController.getTickets('VPN', null, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Search should match only the VPN ticket.');
        System.assertEquals(special.Id, results[0].Id);
    }

    @isTest
    static void testGetTicketsWithStatusFilter() {
        TestDataFactory.createAndInsertTickets(3, 'Medium', 'New');
        TestDataFactory.createAndInsertTickets(2, 'Medium', 'Resolved');

        Test.startTest();
        List<Helpdesk_Ticket__c> results = HelpdeskTicketController.getTickets(null, 'Resolved', null);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return only Resolved tickets.');
    }

    @isTest
    static void testGetTicketsWithPriorityFilter() {
        TestDataFactory.createAndInsertTickets(3, 'Low', 'New');
        TestDataFactory.createAndInsertTickets(2, 'Critical', 'New');

        Test.startTest();
        List<Helpdesk_Ticket__c> results = HelpdeskTicketController.getTickets(null, null, 'Critical');
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return only Critical tickets.');
    }

    @isTest
    static void testUpdateTicketStatus() {
        Helpdesk_Ticket__c t = TestDataFactory.createAndInsertTickets(1, 'Medium', 'New')[0];

        Test.startTest();
        Helpdesk_Ticket__c updated = HelpdeskTicketController.updateTicketStatus(t.Id, 'In Progress');
        Test.stopTest();

        System.assertEquals('In Progress', updated.Status__c, 'Status should be updated to In Progress.');
    }

    @isTest
    static void testUpdateTicketStatusInvalidId() {
        Boolean caughtException = false;

        Test.startTest();
        try {
            HelpdeskTicketController.updateTicketStatus(null, 'Closed');
        } catch (AuraHandledException ex) {
            caughtException = true;
        }
        Test.stopTest();

        System.assert(caughtException, 'Should throw AuraHandledException for null Id.');
    }

    @isTest
    static void testGetTicketMetrics() {
        TestDataFactory.createAndInsertTickets(4, 'High', 'New');
        TestDataFactory.createAndInsertTickets(2, 'Low', 'Resolved');

        Test.startTest();
        Map<String, Integer> metrics = HelpdeskTicketController.getTicketMetrics();
        Test.stopTest();

        System.assertEquals(6, metrics.get('totalTickets'),   'Total should be 6.');
        System.assertEquals(4, metrics.get('openTickets'),     'Open should be 4.');
        System.assertEquals(2, metrics.get('resolvedTickets'), 'Resolved should be 2.');
        System.assert(metrics.containsKey('slaViolatedCount'), 'slaViolatedCount key must exist.');
    }

    /* ═══════════════════════════════════════════════════════════
     *  SERVICE UTILITY TEST
     * ═══════════════════════════════════════════════════════════ */

    @isTest
    static void testGetSlaHoursForPriority() {
        System.assertEquals(4,  HelpdeskTicketService.getSlaHoursForPriority('Critical'));
        System.assertEquals(8,  HelpdeskTicketService.getSlaHoursForPriority('High'));
        System.assertEquals(24, HelpdeskTicketService.getSlaHoursForPriority('Medium'));
        System.assertEquals(72, HelpdeskTicketService.getSlaHoursForPriority('Low'));
        System.assertEquals(null, HelpdeskTicketService.getSlaHoursForPriority('Unknown'));
    }
}
