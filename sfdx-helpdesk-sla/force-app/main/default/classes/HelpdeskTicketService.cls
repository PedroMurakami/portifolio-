/**
 * @description Service layer for Helpdesk_Ticket__c business rules.
 *              Encapsulates all domain logic so it can be invoked from triggers,
 *              controllers, batches or scheduled jobs without duplication.
 *
 *              SLA Rules (hours from creation):
 *                  Critical → 4 h
 *                  High     → 8 h
 *                  Medium   → 24 h  (1 business day)
 *                  Low      → 72 h  (3 business days)
 *
 * @author      Portfolio Project
 */
public with sharing class HelpdeskTicketService {

    /* ───────────────────────── Constants ───────────────────────── */

    private static final Map<String, Integer> SLA_HOURS_BY_PRIORITY = new Map<String, Integer>{
        'Critical' => 4,
        'High'     => 8,
        'Medium'   => 24,
        'Low'      => 72
    };

    private static final Set<String> RESOLVED_STATUSES = new Set<String>{
        'Resolved', 'Closed'
    };

    /* ───────────────────────── Trigger-invoked methods ───────────────────────── */

    /**
     * @description Sets sensible defaults on new tickets.
     *              - Ensures Status is "New" when not explicitly provided.
     * @param tickets  New records (before insert context — no Id yet).
     */
    public static void setDefaults(List<Helpdesk_Ticket__c> tickets) {
        for (Helpdesk_Ticket__c t : tickets) {
            if (String.isBlank(t.Status__c)) {
                t.Status__c = 'New';
            }
            if (String.isBlank(t.Priority__c)) {
                t.Priority__c = 'Medium';
            }
        }
    }

    /**
     * @description Calculates and stamps SLA_Deadline__c based on Priority__c.
     *              Should be called on before-insert so no DML is needed.
     * @param tickets  New records.
     */
    public static void calculateSlaDeadline(List<Helpdesk_Ticket__c> tickets) {
        DateTime now = DateTime.now();
        for (Helpdesk_Ticket__c t : tickets) {
            Integer hours = SLA_HOURS_BY_PRIORITY.get(t.Priority__c);
            if (hours != null) {
                t.SLA_Deadline__c = now.addHours(hours);
            }
        }
    }

    /**
     * @description Recalculates SLA_Deadline__c when Priority__c is changed on an existing ticket.
     *              Uses the original CreatedDate to anchor the new deadline.
     * @param tickets  Updated records (before-update context).
     * @param oldMap   Map of previous record versions.
     */
    public static void recalculateSlaOnPriorityChange(
        List<Helpdesk_Ticket__c> tickets,
        Map<Id, Helpdesk_Ticket__c> oldMap
    ) {
        for (Helpdesk_Ticket__c t : tickets) {
            Helpdesk_Ticket__c old = oldMap.get(t.Id);
            if (t.Priority__c != old.Priority__c) {
                Integer hours = SLA_HOURS_BY_PRIORITY.get(t.Priority__c);
                if (hours != null) {
                    // Anchor on CreatedDate so the SLA window is always relative to ticket creation.
                    DateTime anchor = t.CreatedDate != null ? t.CreatedDate : DateTime.now();
                    t.SLA_Deadline__c = anchor.addHours(hours);
                    // Reset violation flag — it will be re-evaluated below.
                    t.SLA_Violated__c = false;
                }
            }
        }
    }

    /**
     * @description Marks SLA_Violated__c = true when the current time exceeds
     *              SLA_Deadline__c AND the ticket is NOT in a resolved/closed status.
     * @param tickets  Records being updated (before-update context).
     */
    public static void checkSlaViolation(List<Helpdesk_Ticket__c> tickets) {
        DateTime now = DateTime.now();
        for (Helpdesk_Ticket__c t : tickets) {
            if (t.SLA_Deadline__c != null && !RESOLVED_STATUSES.contains(t.Status__c)) {
                if (now > t.SLA_Deadline__c) {
                    t.SLA_Violated__c = true;
                }
            }
        }
    }

    /* ───────────────────────── Utility / Query helpers ───────────────────────── */

    /**
     * @description Returns the SLA hours configured for a given priority value.
     * @param priority  Picklist API value (e.g. "High").
     * @return Number of SLA hours, or null if the priority is unknown.
     */
    public static Integer getSlaHoursForPriority(String priority) {
        return SLA_HOURS_BY_PRIORITY.get(priority);
    }
}
