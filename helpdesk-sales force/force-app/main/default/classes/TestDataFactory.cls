/**
 * @description Test-data factory following the "TestDataFactory" pattern.
 *              Centralises record creation for all test classes — avoids
 *              duplicated setup code and makes bulk tests trivial.
 * @author      Portfolio Project
 */
@isTest
public class TestDataFactory {

    /**
     * @description Creates a list of Helpdesk_Ticket__c records WITHOUT inserting them.
     * @param count     Number of records to generate.
     * @param priority  Priority picklist value (e.g. "High").
     * @param status    Status picklist value (e.g. "New").
     * @return List of unsaved Helpdesk_Ticket__c records.
     */
    public static List<Helpdesk_Ticket__c> createTickets(Integer count, String priority, String status) {
        List<Helpdesk_Ticket__c> tickets = new List<Helpdesk_Ticket__c>();
        for (Integer i = 0; i < count; i++) {
            tickets.add(new Helpdesk_Ticket__c(
                Title__c       = 'Test Ticket ' + i,
                Description__c = 'Auto-generated test ticket number ' + i,
                Priority__c    = priority,
                Status__c      = status
            ));
        }
        return tickets;
    }

    /**
     * @description Creates and INSERTS a list of Helpdesk_Ticket__c records.
     * @param count     Number of records.
     * @param priority  Priority picklist value.
     * @param status    Status picklist value.
     * @return Inserted records (with Ids).
     */
    public static List<Helpdesk_Ticket__c> createAndInsertTickets(Integer count, String priority, String status) {
        List<Helpdesk_Ticket__c> tickets = createTickets(count, priority, status);
        insert tickets;
        return tickets;
    }
}
