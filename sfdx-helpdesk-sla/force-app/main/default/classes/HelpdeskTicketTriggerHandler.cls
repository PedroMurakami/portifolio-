/**
 * @description Trigger Handler for Helpdesk_Ticket__c.
 *              Orchestrates event-specific logic by delegating to HelpdeskTicketService.
 *              Pattern: keeps the trigger handler thin — only routing, no raw business rules.
 * @author      Portfolio Project
 */
public with sharing class HelpdeskTicketTriggerHandler {

    /**
     * @description Handles before-insert events.
     *              - Sets default Status to "New".
     *              - Calculates the SLA Deadline based on Priority.
     * @param newTickets  List of new Helpdesk_Ticket__c records being inserted.
     */
    public void beforeInsert(List<Helpdesk_Ticket__c> newTickets) {
        HelpdeskTicketService.setDefaults(newTickets);
        HelpdeskTicketService.calculateSlaDeadline(newTickets);
    }

    /**
     * @description Handles before-update events.
     *              - Recalculates SLA Deadline when Priority changes.
     *              - Checks for SLA violations on every update.
     * @param newTickets  List of updated Helpdesk_Ticket__c records.
     * @param oldMap      Map of old record versions keyed by Id.
     */
    public void beforeUpdate(List<Helpdesk_Ticket__c> newTickets, Map<Id, Helpdesk_Ticket__c> oldMap) {
        HelpdeskTicketService.recalculateSlaOnPriorityChange(newTickets, oldMap);
        HelpdeskTicketService.checkSlaViolation(newTickets);
    }
}
