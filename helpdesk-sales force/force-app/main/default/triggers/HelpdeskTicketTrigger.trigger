/**
 * @description Trigger for Helpdesk_Ticket__c — delegates all logic to HelpdeskTicketTriggerHandler.
 *              Follows best practice: ONE trigger per object, ZERO business logic inside trigger body.
 * @author      Portfolio Project
 */
trigger HelpdeskTicketTrigger on Helpdesk_Ticket__c (before insert, before update) {
    HelpdeskTicketTriggerHandler handler = new HelpdeskTicketTriggerHandler();

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
