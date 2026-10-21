import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getTickets from '@salesforce/apex/HelpdeskTicketController.getTickets';
import getTicketMetrics from '@salesforce/apex/HelpdeskTicketController.getTicketMetrics';
import updateTicketStatus from '@salesforce/apex/HelpdeskTicketController.updateTicketStatus';

/* ───────────────────────── Constants ───────────────────────── */

const STATUS_OPTIONS = [
    { label: 'All Statuses', value: '' },
    { label: 'New', value: 'New' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Waiting', value: 'Waiting' },
    { label: 'Resolved', value: 'Resolved' },
    { label: 'Closed', value: 'Closed' }
];

const PRIORITY_OPTIONS = [
    { label: 'All Priorities', value: '' },
    { label: 'Low', value: 'Low' },
    { label: 'Medium', value: 'Medium' },
    { label: 'High', value: 'High' },
    { label: 'Critical', value: 'Critical' }
];

const ALL_STATUS_OPTIONS = STATUS_OPTIONS.filter(o => o.value !== '');

const PRIORITY_CLASS_MAP = {
    Low:      'slds-badge badge-priority badge-low',
    Medium:   'slds-badge badge-priority badge-medium',
    High:     'slds-badge badge-priority badge-high',
    Critical: 'slds-badge badge-priority badge-critical'
};

const STATUS_CLASS_MAP = {
    'New':         'slds-badge badge-status badge-new',
    'In Progress': 'slds-badge badge-status badge-in-progress',
    'Waiting':     'slds-badge badge-status badge-waiting',
    'Resolved':    'slds-badge badge-status badge-resolved',
    'Closed':      'slds-badge badge-status badge-closed'
};

const SLA_AT_RISK_HOURS = 2;

/* ───────────────────────── Component ───────────────────────── */

export default class TicketBoard extends LightningElement {

    /* ---- Reactive state ---- */
    @track tickets = [];
    @track searchTerm = '';
    @track filterStatus = '';
    @track filterPriority = '';
    @track isLoading = true;

    /* Metrics */
    metricTotal = 0;
    metricOpen = 0;
    metricResolved = 0;
    metricViolated = 0;

    /* Wire cache refs for refreshApex */
    _wiredTickets;
    _wiredMetrics;

    /* Debounce timer id */
    _searchTimer;

    /* ---- Options getters ---- */
    get statusOptions()    { return STATUS_OPTIONS; }
    get priorityOptions()  { return PRIORITY_OPTIONS; }
    get allStatusOptions() { return ALL_STATUS_OPTIONS; }

    /* ---- Computed getters ---- */
    get isEmpty()      { return !this.isLoading && this.tickets.length === 0; }
    get hasTickets()   { return !this.isLoading && this.tickets.length > 0; }

    /* ═══════════════ WIRED DATA ═══════════════ */

    @wire(getTickets, {
        searchTerm: '$searchTerm',
        status: '$filterStatus',
        priority: '$filterPriority'
    })
    wiredTickets(result) {
        this._wiredTickets = result;
        this.isLoading = false;
        if (result.data) {
            this.tickets = result.data.map(t => this._enrichTicket(t));
        } else if (result.error) {
            this._showError(result.error);
            this.tickets = [];
        }
    }

    @wire(getTicketMetrics)
    wiredMetrics(result) {
        this._wiredMetrics = result;
        if (result.data) {
            this.metricTotal    = result.data.totalTickets    || 0;
            this.metricOpen     = result.data.openTickets     || 0;
            this.metricResolved = result.data.resolvedTickets || 0;
            this.metricViolated = result.data.slaViolatedCount || 0;
        }
    }

    /* ═══════════════ EVENT HANDLERS ═══════════════ */

    handleSearchChange(event) {
        clearTimeout(this._searchTimer);
        const val = event.target.value;
        // Debounce 350 ms to avoid excessive Apex calls.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimer = setTimeout(() => {
            this.searchTerm = val;
        }, 350);
    }

    handleStatusFilter(event) {
        this.filterStatus = event.detail.value;
    }

    handlePriorityFilter(event) {
        this.filterPriority = event.detail.value;
    }

    handleQuickStatusChange(event) {
        const ticketId = event.target.dataset.ticketId;
        const newStatus = event.detail.value;

        this.isLoading = true;
        updateTicketStatus({ ticketId, newStatus })
            .then(() => {
                this._toast('Success', `Status updated to "${newStatus}".`, 'success');
                return Promise.all([
                    refreshApex(this._wiredTickets),
                    refreshApex(this._wiredMetrics)
                ]);
            })
            .catch(error => {
                this._showError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ═══════════════ PRIVATE HELPERS ═══════════════ */

    /**
     * Enriches a raw Apex record with computed UI properties:
     *   - priorityBadgeClass / statusBadgeClass (SLDS badge colours)
     *   - isSlaAtRisk (boolean — within 2 h of deadline)
     *   - cardClass  (border highlight for violated / at-risk tickets)
     */
    _enrichTicket(record) {
        const t = { ...record };

        t.priorityBadgeClass = PRIORITY_CLASS_MAP[t.Priority__c] || 'slds-badge';
        t.statusBadgeClass   = STATUS_CLASS_MAP[t.Status__c]     || 'slds-badge';

        // SLA at risk: within 2 hours AND not yet violated AND not resolved/closed.
        const deadline = t.SLA_Deadline__c ? new Date(t.SLA_Deadline__c) : null;
        const now = new Date();
        const hoursRemaining = deadline ? (deadline - now) / 3600000 : null;
        t.isSlaAtRisk = (
            hoursRemaining !== null &&
            hoursRemaining > 0 &&
            hoursRemaining <= SLA_AT_RISK_HOURS &&
            !t.SLA_Violated__c &&
            t.Status__c !== 'Resolved' &&
            t.Status__c !== 'Closed'
        );

        // Card border class
        if (t.SLA_Violated__c) {
            t.cardClass = 'slds-card ticket-card card-violated';
        } else if (t.isSlaAtRisk) {
            t.cardClass = 'slds-card ticket-card card-at-risk';
        } else {
            t.cardClass = 'slds-card ticket-card';
        }

        return t;
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _showError(error) {
        const msg = error?.body?.message || error?.message || 'Unknown error';
        this._toast('Error', msg, 'error');
    }
}
