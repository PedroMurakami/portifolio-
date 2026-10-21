/**
 * @description Apex controller exposing @AuraEnabled methods to the ticketBoard LWC.
 *              Every public method wraps logic in try/catch and throws
 *              AuraHandledException so the UI receives user-friendly error messages.
 * @author      Portfolio Project
 */
public with sharing class HelpdeskTicketController {

    /* ─────────────── Query: filtered ticket list ─────────────── */

    /**
     * @description Retrieves tickets with optional filters (search text, status, priority).
     * @param searchTerm  Free-text search applied to Title__c (LIKE %term%).
     * @param status      Picklist value to filter Status__c.  Pass null/blank to skip.
     * @param priority    Picklist value to filter Priority__c. Pass null/blank to skip.
     * @return List of matching Helpdesk_Ticket__c records (max 2 000).
     */
    @AuraEnabled(cacheable=true)
    public static List<Helpdesk_Ticket__c> getTickets(String searchTerm, String status, String priority) {
        try {
            String query = 'SELECT Id, Name, Title__c, Description__c, Status__c, Priority__c, '
                         + 'SLA_Deadline__c, SLA_Violated__c, Assigned_Agent__c, Assigned_Agent__r.Name, '
                         + 'CreatedDate '
                         + 'FROM Helpdesk_Ticket__c';

            List<String> conditions = new List<String>();

            if (String.isNotBlank(searchTerm)) {
                String safeTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
                conditions.add('Title__c LIKE \'' + safeTerm + '\'');
            }
            if (String.isNotBlank(status)) {
                conditions.add('Status__c = \'' + String.escapeSingleQuotes(status) + '\'');
            }
            if (String.isNotBlank(priority)) {
                conditions.add('Priority__c = \'' + String.escapeSingleQuotes(priority) + '\'');
            }

            if (!conditions.isEmpty()) {
                query += ' WHERE ' + String.join(conditions, ' AND ');
            }

            query += ' ORDER BY SLA_Deadline__c ASC NULLS LAST LIMIT 2000';

            return Database.query(query);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /* ─────────────── Action: update ticket status ─────────────── */

    /**
     * @description Updates the Status__c of a single ticket.
     *              The before-update trigger will automatically check SLA violations.
     * @param ticketId   Record Id.
     * @param newStatus  Target status picklist value.
     * @return The updated Helpdesk_Ticket__c record.
     */
    @AuraEnabled
    public static Helpdesk_Ticket__c updateTicketStatus(Id ticketId, String newStatus) {
        try {
            Helpdesk_Ticket__c ticket = [
                SELECT Id, Status__c
                FROM Helpdesk_Ticket__c
                WHERE Id = :ticketId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            ticket.Status__c = newStatus;
            update ticket;

            // Re-query to return refreshed data to the UI.
            return [
                SELECT Id, Name, Title__c, Description__c, Status__c, Priority__c,
                       SLA_Deadline__c, SLA_Violated__c, Assigned_Agent__c, Assigned_Agent__r.Name,
                       CreatedDate
                FROM Helpdesk_Ticket__c
                WHERE Id = :ticketId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /* ─────────────── Dashboard: summary metrics ─────────────── */

    /**
     * @description Returns aggregate metrics for a dashboard header:
     *              totalTickets, openTickets, resolvedTickets, slaViolatedCount.
     * @return Map with String keys and Integer values.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getTicketMetrics() {
        try {
            Map<String, Integer> metrics = new Map<String, Integer>();

            Integer total = [SELECT COUNT() FROM Helpdesk_Ticket__c];
            Integer open  = [SELECT COUNT() FROM Helpdesk_Ticket__c WHERE Status__c NOT IN ('Resolved', 'Closed')];
            Integer resolved = [SELECT COUNT() FROM Helpdesk_Ticket__c WHERE Status__c IN ('Resolved', 'Closed')];
            Integer violated = [SELECT COUNT() FROM Helpdesk_Ticket__c WHERE SLA_Violated__c = true];

            metrics.put('totalTickets', total);
            metrics.put('openTickets', open);
            metrics.put('resolvedTickets', resolved);
            metrics.put('slaViolatedCount', violated);

            return metrics;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
}
